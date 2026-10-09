import {json,authorize,postOnly} from '../../lib/http.js';
export async function POST(request){
 const denied=postOnly(request)||authorize(request);if(denied)return denied;
 let body;try{body=await request.json();}catch{return json({success:false,error:'Invalid JSON'},400);}
 const {amount,jobId}=body;
 const paise=Math.round(amount*100);
 if(typeof amount!=='number'||!Number.isFinite(amount)||amount<=0||!Number.isSafeInteger(paise)||paise<100||typeof jobId!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(jobId))return json({success:false,error:'Provide a positive INR amount (at least ₹1) and a valid job UUID'},400);
 if(!process.env.RAZORPAY_KEY_ID||!process.env.RAZORPAY_KEY_SECRET)return json({success:false,error:'Payments are not configured'},503);
 try{
 const result=await fetch('https://api.razorpay.com/v1/orders',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Basic '+Buffer.from(process.env.RAZORPAY_KEY_ID+':'+process.env.RAZORPAY_KEY_SECRET).toString('base64')},body:JSON.stringify({amount:paise,currency:'INR',receipt:'rcpt_job_'+jobId.slice(0,8),notes:{job_id:jobId,app_name:'bolokaam.app'}}),signal:AbortSignal.timeout(20000)});
 if(!result.ok)return json({success:false,error:'Payment provider could not create the order'},502);
 return json({success:true,order:await result.json()});
 }catch(error){console.error('Create order failed',error.name);return json({success:false,error:'Payment provider unavailable'},502);}
}
