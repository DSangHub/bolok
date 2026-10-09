import {createHmac,timingSafeEqual} from 'node:crypto';
import {json,authorize,postOnly} from '../../lib/http.js';
export async function POST(request){
 const denied=postOnly(request)||authorize(request);if(denied)return denied;
 let body;try{body=await request.json();}catch{return json({success:false,error:'Invalid JSON'},400);}
 const {razorpay_order_id:order,razorpay_payment_id:payment,razorpay_signature:signature}=body;
 if(typeof order!=='string'||!/^order_[a-zA-Z0-9]+$/.test(order)||typeof payment!=='string'||!/^pay_[a-zA-Z0-9]+$/.test(payment)||typeof signature!=='string'||!/^[a-fA-F0-9]{64}$/.test(signature))return json({success:false,error:'Invalid payment fields'},400);
 if(!process.env.RAZORPAY_KEY_SECRET)return json({success:false,error:'Payments are not configured'},503);
 const expected=createHmac('sha256',process.env.RAZORPAY_KEY_SECRET).update(order+'|'+payment).digest();
 const valid=timingSafeEqual(expected,Buffer.from(signature,'hex'));
 return json({success:valid,message:valid?'Payment signature verified':'Invalid payment signature'},valid?200:400);
}
