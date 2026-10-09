export const json=(body,status=200)=>Response.json(body,{status});
export function authorize(request){
 const token=process.env.BOLOK_API_TOKEN;
 if(!token) return json({success:false,error:'API access is not configured'},503);
 if(request.headers.get('authorization')!=='Bearer '+token) return json({success:false,error:'Unauthorized'},401);
}
export function postOnly(request){if(request.method!=='POST')return json({success:false,error:'Use POST'},405);}
