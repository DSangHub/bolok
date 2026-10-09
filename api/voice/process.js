import {json,authorize,postOnly} from '../../lib/http.js';
export async function POST(request){
 const denied=postOnly(request)||authorize(request);if(denied)return denied;
 let form;try{form=await request.formData();}catch{return json({success:false,error:'Send multipart/form-data with an audio file'},400);}
 const audio=form.get('audio'),language=form.get('language')||'hi-IN';
 if(!audio||typeof audio.arrayBuffer!=='function'||audio.size===0)return json({success:false,error:'Audio file is required'},400);
 if(audio.size>4*1024*1024)return json({success:false,error:'Audio must be 4MB or smaller'},413);
 if(!['hi-IN','pa-IN','mr-IN','ta-IN','te-IN','bn-IN','gu-IN','kn-IN','ml-IN','en-IN'].includes(language))return json({success:false,error:'Unsupported language'},400);
 const encoding=audio.type.includes('webm')?'WEBM_OPUS':audio.type.includes('wav')?'LINEAR16':null;
 if(!encoding)return json({success:false,error:'Use WebM/Opus or WAV audio'},400);
 if(!process.env.GOOGLE_SERVICE_ACCOUNT_JSON)return json({success:false,error:'Speech recognition is not configured'},503);
 try{
 const {v1}=await import('@google-cloud/speech');
 const credentials=JSON.parse(process.env.GOOGLE_SERVICE_ACCOUNT_JSON);
 const client=new v1.SpeechClient({credentials,projectId:credentials.project_id});
 try{
 const [response]=await client.recognize({audio:{content:Buffer.from(await audio.arrayBuffer()).toString('base64')},config:{encoding,...(encoding==='WEBM_OPUS'?{sampleRateHertz:48000}:{}),languageCode:language,enableAutomaticPunctuation:true}});
 return json({success:true,transcript:(response.results||[]).map(r=>r.alternatives?.[0]?.transcript||'').join('\n'),audioSizeKb:Math.round(audio.size/1024)});
 }finally{await client.close();}
 }catch(error){console.error('Speech processing failed',error.name);return json({success:false,error:'Speech recognition failed'},502);}
}
