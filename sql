-- Enable PostGIS for geospatial matching and UUID extension for secure identifiers
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. ENUMS FOR APPLICATION STATES
CREATE TYPE user_role AS ENUM ('worker', 'employer', 'contractor', 'transporter');
CREATE TYPE job_status AS ENUM ('draft', 'active', 'filled', 'completed', 'cancelled');
CREATE TYPE match_status AS ENUM ('pinged', 'accepted', 'rejected', 'expired', 'completed');
CREATE TYPE payment_status AS ENUM ('pending', 'captured', 'failed', 'refunded');

-- 2. USERS & PROFILES TABLE
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone_number VARCHAR(15) UNIQUE NOT NULL,
    role user_role NOT NULL,
    full_name VARCHAR(100),
    preferred_language VARCHAR(10) DEFAULT 'hi-IN', -- e.g., hi-IN, pa-IN, mr-IN, ta-IN
    profile_audio_url TEXT,                        -- URL to 15s voice bio in cloud storage
    fcm_token TEXT,                                -- Firebase Cloud Messaging token for 5 AM pings
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 3. WORKER PROFILES & AVAILABILITY TABLE
CREATE TABLE worker_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    primary_category VARCHAR(50) NOT NULL,        -- e.g., 'mason', 'driver', 'loader', 'painter'
    sub_categories TEXT[],                         -- e.g., ['tile_layer', 'plaster']
    min_daily_wage DECIMAL(10, 2),                 -- Minimum expected daily pay in INR
    desired_ping_time TIME DEFAULT '05:00:00',     -- Custom morning notification time
    search_radius_km INT DEFAULT 10,               -- Max commute distance in kilometers
    current_location GEOGRAPHY(POINT, 4326),      -- PostGIS point (Longitude, Latitude)
    is_available BOOLEAN DEFAULT TRUE,             -- Daily availability toggle
    last_available_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Index for fast spatial queries on worker locations
CREATE INDEX idx_worker_location ON worker_profiles USING GIST (current_location);
CREATE INDEX idx_worker_avail ON worker_profiles (is_available, primary_category);

-- 4. BUSINESS & CONTRACTOR PROFILES
CREATE TABLE business_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    company_or_trade_name VARCHAR(120),
    gstin VARCHAR(15),
    razorpay_customer_id VARCHAR(50),               -- Razorpay customer mapping
    wallet_balance DECIMAL(10, 2) DEFAULT 0.00,    -- Pre-funded balance for job postings/escrow
    business_location GEOGRAPHY(POINT, 4326)
);

-- 5. JOB POSTINGS TABLE
CREATE TABLE jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category VARCHAR(50) NOT NULL,
    job_audio_prompt_url TEXT,                     -- Audio description recorded by employer
    transcribed_text TEXT,                         -- Speech-to-text transcript
    workers_needed INT DEFAULT 1,
    daily_wage DECIMAL(10, 2) NOT NULL,            -- Wage offered per worker in INR
    work_date DATE NOT NULL,
    work_location GEOGRAPHY(POINT, 4326) NOT NULL,
    location_address TEXT,                         -- Landmarked descriptive address
    status job_status DEFAULT 'active',
    fee_amount DECIMAL(10, 2) DEFAULT 0.00,        -- Platform fee / commission
    fee_paid BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Spatial index for finding jobs near a worker
CREATE INDEX idx_job_location ON jobs USING GIST (work_location);
CREATE INDEX idx_job_matching ON jobs (status, work_date, category);

-- 6. MATCHES & 5 AM PING SCHEDULE TABLE
CREATE TABLE job_matches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    worker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    distance_km DECIMAL(6, 2),                     -- Calculated distance at match time
    match_score DECIMAL(5, 2),                     -- AI/Rule relevance score
    status match_status DEFAULT 'pinged',
    ping_scheduled_at TIMESTAMPTZ NOT NULL,        -- Scheduled timestamp for FCM 5 AM audio push
    ping_sent_at TIMESTAMPTZ,                      -- Actual dispatch timestamp
    worker_response_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (job_id, worker_id)
);

-- Index for the overnight 5 AM worker dispatch queue
CREATE INDEX idx_pending_pings ON job_matches (ping_scheduled_at, status) WHERE status = 'pinged';

-- 7. TRANSACTIONS & RAZORPAY BILLING TABLE
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id),
    job_id UUID REFERENCES jobs(id),
    razorpay_payment_id VARCHAR(100),
    razorpay_order_id VARCHAR(100),
    razorpay_signature VARCHAR(255),
    amount DECIMAL(10, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'INR',
    status payment_status DEFAULT 'pending',
    payment_method VARCHAR(30),                    -- UPI, Netbanking, Card, Wallet
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);SELECT 
    j.id AS job_id,
    j.category,
    j.daily_wage,
    j.job_audio_prompt_url,
    ROUND((ST_Distance(j.work_location, w.current_location) / 1000)::numeric, 2) AS distance_in_km
FROM jobs j
JOIN worker_profiles w ON w.user_id = 'WORKER_UUID_HERE'
WHERE j.status = 'active'
  AND j.work_date = CURRENT_DATE + INTERVAL '1 day'
  AND j.category = w.primary_category
  AND ST_DWithin(j.work_location, w.current_location, w.search_radius_km * 1000)
ORDER BY distance_in_km ASC
LIMIT 10;
