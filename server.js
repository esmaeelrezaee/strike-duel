import express from 'express';
import {createServer} from 'node:http';
import {WebSocketServer,WebSocket} from 'ws';
import {randomBytes} from 'node:crypto';
const app=express();app.use(express.static('public'));const server=createServer(app);const wss=new WebSocketServer({server});const rooms=new Map();
const send=(ws,data)=>{if(ws?.readyState===WebSocket.OPEN)ws.send(JSON.stringify(data))};
const broadcast=(room,data)=>room.players.forEach(p=>send(p.ws,data));
const cleanCode=c=>String(c||'').toUpperCase().replace(/[^A-Z0-9]/g,'').slice(0,6);
const spawn=i=>({x:i?12:-12,y:1.7,z:i?12:-12,yaw:i?Math.PI:0,pitch:0,hp:100,ammo:30,kills:0,deaths:0,alive:true});
function state(room){broadcast(room,{t:'state',players:room.players.map(p=>({id:p.id,...p.state})),count:room.players.length})}
function remove(ws){const room=ws.room;if(!room)return;room.players=room.players.filter(p=>p.ws!==ws);if(!room.players.length)rooms.delete(room.code);else state(room);ws.room=null}
wss.on('connection',ws=>{ws.on('message',raw=>{if(raw.length>2048)return;let m;try{m=JSON.parse(raw)}catch{return}if(!m||typeof m!=='object')return;
if(m.t==='join'){remove(ws);let code=cleanCode(m.code);if(!code){do{code=randomBytes(3).toString('hex').toUpperCase()}while(rooms.has(code))}let room=rooms.get(code);if(!room){room={code,players:[]};rooms.set(code,room)}if(room.players.length>=2){send(ws,{t:'error',message:'اتاق پر است'});return}const id=room.players.length?1:0;const p={id,ws,state:spawn(id),lastShot:0};room.players.push(p);ws.room=room;ws.player=p;send(ws,{t:'joined',code,id});state(room);return}
const room=ws.room,p=ws.player;if(!room||!room.players.includes(p))return;
if(m.t==='move'){const s=p.state;if(!s.alive)return;const x=Number(m.x),z=Number(m.z),yaw=Number(m.yaw),pitch=Number(m.pitch);if(![x,z,yaw,pitch].every(Number.isFinite))return;const dx=x-s.x,dz=z-s.z;if(Math.hypot(dx,dz)>3)return;s.x=Math.max(-23,Math.min(23,x));s.z=Math.max(-23,Math.min(23,z));s.yaw=yaw;s.pitch=Math.max(-1.35,Math.min(1.35,pitch));state(room)}
if(m.t==='reload'&&p.state.alive){p.state.ammo=30;state(room)}
if(m.t==='shoot'&&p.state.alive){const now=Date.now();if(now-p.lastShot<135||p.state.ammo<=0)return;p.lastShot=now;p.state.ammo--;const target=room.players.find(q=>q!==p&&q.state.alive);if(target){const a=p.state,b=target.state;const dx=b.x-a.x,dz=b.z-a.z;const dist=Math.hypot(dx,dz);const dirx=-Math.sin(a.yaw),dirz=-Math.cos(a.yaw);const dot=(dx*dirx+dz*dirz)/Math.max(dist,.001);const pitchTo=Math.atan2((b.y-a.y),dist);if(dist<48&&dot>Math.cos(.15)&&Math.abs(a.pitch-pitchTo)<.2){b.hp=Math.max(0,b.hp-25);if(!b.hp){b.alive=false;p.state.kills++;b.deaths++;broadcast(room,{t:'kill',by:p.id});setTimeout(()=>{if(room.players.includes(target)){target.state={...spawn(target.id),kills:target.state.kills,deaths:target.state.deaths};state(room)}},2500)}}}broadcast(room,{t:'fire',id:p.id});state(room)}
});ws.on('close',()=>remove(ws));ws.on('error',()=>remove(ws))});
const port=process.env.PORT||3000;server.listen(port,'0.0.0.0',()=>console.log(`Strike Duel http://localhost:${port}`));
