const multer = require('multer');

// Store audio file in memory buffer for immediate API stream processing
const storage = multer.memoryStorage();

const audioFilter = (req, file, cb) => {
  if (file.mimetype.startsWith('audio/') || file.mimetype.includes('octet-stream')) {
    cb(null, true);
  } else {
    cb(new Error('Only audio recordings are permitted!'), false);
  }
};

const upload = multer({
  storage: storage,
  fileFilter: audioFilter,
  limits: { fileSize: 10 * 1024 * 1024 } // 10MB limit
});

module.exports = upload;const { SpeechClient } = require('@google-cloud/speech').v1p1beta1;
const speechClient = new SpeechClient();

/**
 * Transcribes audio buffer using Google Cloud Speech-to-Text
 * @param {Buffer} audioBuffer - Audio file buffer from req.file
 * @param {string} primaryLanguageCode - e.g., 'hi-IN', 'pa-IN', 'mr-IN'
 */
async function transcribeAudio(audioBuffer, primaryLanguageCode = 'hi-IN') {
  const audio = {
    content: audioBuffer.toString('base64')
  };

  const config = {
    encoding: 'WEBM_OPUS', // Standard format from Flutter / Mobile audio recording
    sampleRateHertz: 48000,
    languageCode: primaryLanguageCode,
    // Enable multi-dialect recognition for Indic markets
    alternativeLanguageCodes: ['hi-IN', 'pa-IN', 'mr-IN', 'ta-IN', 'te-IN', 'bn-IN'],
    enableAutomaticPunctuation: true,
    model: 'latest_long'
  };

  const request = {
    audio: audio,
    config: config
  };

  const [response] = await speechClient.recognize(request);
  const transcription = response.results
    .map(result => result.alternatives[0].transcript)
    .join('\n');

  return transcription || 'No audible speech detected';
}

module.exports = { transcribeAudio };const Razorpay = require('razorpay');
const crypto = require('crypto');

const razorpayInstance = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET
});

/**
 * Creates an order in Razorpay
 * @param {number} amountInRupees - Wage or deposit amount in INR
 * @param {string} jobId - Associated database Job UUID
 */
async function createJobOrder(amountInRupees, jobId) {
  const options = {
    amount: Math.round(amountInRupees * 100), // Convert INR to Paise
    currency: 'INR',
    receipt: `rcpt_job_${jobId.substring(0, 8)}`,
    notes: {
      job_id: jobId,
      app_name: 'bolokaam.app'
    }
  };

  return await razorpayInstance.orders.create(options);
}

/**
 * Verifies Razorpay Webhook / Checkout Signature
 */
function verifyPaymentSignature(orderId, paymentId, signature) {
  const body = orderId + '|' + paymentId;
  const expectedSignature = crypto
    .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
    .update(body.toString())
    .digest('hex');

  return expectedSignature === signature;
}

module.exports = { createJobOrder, verifyPaymentSignature };const express = require('express');
const router = express.Router();
const upload = require('../middleware/upload');
const { transcribeAudio } = require('../services/speechService');

// POST /api/voice/process - Accepts voice audio from mobile app
router.post('/process', upload.single('audio'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, error: 'Audio file is required' });
    }

    const lang = req.body.language || 'hi-IN';
    const transcript = await transcribeAudio(req.file.buffer, lang);

    // Return transcribed text so backend/AI can extract intent & save profile audio
    res.status(200).json({
      success: true,
      transcript: transcript,
      audioSizeKb: Math.round(req.file.size / 1024)
    });
  } catch (err) {
    console.error('Voice Processing Error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});
const express = require('express');
const router = express.Router();
const { createJobOrder, verifyPaymentSignature } = require('../services/razorpayService');

// POST /api/payment/create-order - Contractor creates a deposit/fee order
router.post('/create-order', async (req, res) => {
  try {
    const { amount, jobId } = req.body;
    if (!amount || !jobId) {
      return res.status(400).json({ success: false, error: 'Amount and jobId are required' });
    }

    const order = await createJobOrder(amount, jobId);
    res.status(200).json({ success: true, order });
  } catch (err) {
    console.error('Razorpay Order Error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

// POST /api/payment/verify - Verifies payment signature after mobile checkout
router.post('/verify', async (req, res) => {
  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body;

    const isValid = verifyPaymentSignature(
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature
    );

    if (isValid) {
      // TODO: Update job status in database to 'active' or mark fee as paid
      res.status(200).json({ success: true, message: 'Payment verified successfully' });
    } else {
      res.status(400).json({ success: false, message: 'Invalid payment signature' });
    }
  } catch (err) {
    console.error('Razorpay Verify Error:', err);
    res.status(500).json({ success: false, error: err.message });
  }
});

module.exports = router;require('dotenv').config();
const express = require('express');
const cors = require('cors');

const voiceRoutes = require('./routes/voice');
const paymentRoutes = require('./routes/payment');

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Register Bolokaam API routes
app.use('/api/voice', voiceRoutes);
app.use('/api/payment', paymentRoutes);

app.get('/health', (req, res) => res.send('BoloKaam Engine Operational'));

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`BoloKaam backend listening on port ${PORT}`);
});
module.exports = router;
