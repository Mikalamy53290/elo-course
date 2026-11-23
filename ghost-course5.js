(function(){
"use strict";
var $=function(id){return document.getElementById(id);}, colors=["#278A50","#38BDF8","#F59E0B","#E879F9","#F87171"];
var people=[],races=[],results=[],runners=[],distance=10,elapsed=0,playing=false,speed=1,raf=0,last=0;
var canvas=$("c5-canvas"),ctx=canvas.getContext("2d");
function norm(v){return String(v||"").normalize("NFD").replace(/[\u0300-\u036f]/g,"").toLowerCase().replace(/[^a-z0-9]+/g," ").trim();}
function seconds(v){if(typeof v==="number"&&isFinite(v))return v;var p=String(v||"").trim().split(":").map(Number);if(!p.length||p.some(function(x){return !Number.isFinite(x);}))return 0;return p.reduce(function(a,x){return a*60+x;},0);}
function fmt(v){v=Math.max(0,Math.floor(v));return [Math.floor(v/3600),Math.floor(v%3600/60),v%60].map(function(x){return String(x).padStart(2,"0");}).join(":");}
function pause(){playing=false;if(raf)cancelAnimationFrame(raf);raf=0;$("c5-play").textContent="▶ Démarrer";}
function getRace(){return races.find(function(r){return String(r.id)===$("c5-race").value;});}
function getPerson(value){var q=norm(value);return people.find(function(p){return norm(p.name)===q||norm(p.fullName)===q;})||null;}
function applyTimes(){runners.forEach(function(r){var found=results.find(function(x){return String(x.id)===String(r.id);});r.official=!!found;r.time=found?seconds(found.time):seconds(r.manual);r.rank=found?found.rank:null;});}
function renderCards(){
 var root=$("c5-runners");root.innerHTML="";
 runners.forEach(function(r,i){
  var card=document.createElement("div");card.className="c5-card";
  var title=document.createElement("strong");title.textContent="Coureur "+(i+1);title.style.color=colors[i];card.appendChild(title);
  var lab=document.createElement("label");lab.textContent="Rechercher un coureur ELO COURSE";card.appendChild(lab);
  var input=document.createElement("input");input.setAttribute("list","c5-directory");input.dataset.runner=i;input.placeholder="Nom ou prénom";input.value=r.name||"";card.appendChild(input);
  lab=document.createElement("label");lab.textContent="Chrono manuel si absent des résultats";card.appendChild(lab);
  var chrono=document.createElement("input");chrono.dataset.manual=i;chrono.placeholder="00:44:30";chrono.value=r.manual||"";card.appendChild(chrono);
  var status=document.createElement("div");status.style.cssText="font-size:11px;color:#94A3B8;margin-top:5px";status.textContent=r.official?"Chrono officiel : "+fmt(r.time):(r.id?"Pas de résultat sur cette course — chrono manuel possible":"Choisis un profil");card.appendChild(status);
  root.appendChild(card);
 });
 $("c5-add").disabled=runners.length>=5;
 $("c5-add").textContent=runners.length>=5?"Maximum 5 coureurs atteint":"+ Ajouter un coureur";
}
function draw(){
 var w=canvas.clientWidth,h=canvas.clientHeight;if(!w||!h)return;
 var d=Math.min(window.devicePixelRatio||1,2);if(canvas.width!==Math.round(w*d)||canvas.height!==Math.round(h*d)){canvas.width=Math.round(w*d);canvas.height=Math.round(h*d);}
 ctx.setTransform(d,0,0,d,0,0);ctx.clearRect(0,0,w,h);ctx.fillStyle="#0B1724";ctx.fillRect(0,0,w,h);
 var cx=w/2,cy=h/2,rx=Math.max(55,w*.36),ry=Math.max(45,h*.31);
 ctx.beginPath();ctx.ellipse(cx,cy,rx,ry,0,0,Math.PI*2);ctx.strokeStyle="#294155";ctx.lineWidth=28;ctx.stroke();
 ctx.beginPath();ctx.ellipse(cx,cy,rx,ry,0,0,Math.PI*2);ctx.strokeStyle="#278A50";ctx.lineWidth=4;ctx.stroke();
 ctx.textAlign="center";ctx.fillStyle="#F1F5F9";ctx.font="bold 14px sans-serif";ctx.fillText(getRace()?getRace().name:"Course à 5",cx,cy-9);
 ctx.fillStyle="#94A3B8";ctx.font="12px sans-serif";ctx.fillText(distance.toFixed(2)+" km · Départ / arrivée",cx,cy+12);
 var valid=runners.map(function(r,i){return Object.assign({index:i},r);}).filter(function(r){return r.time>0;});
 valid.forEach(function(r){var progress=Math.min(.999,Math.max(0,elapsed/r.time)),a=-Math.PI/2+progress*Math.PI*2,x=cx+Math.cos(a)*rx,y=cy+Math.sin(a)*ry;
  ctx.beginPath();ctx.arc(x,y,9,0,Math.PI*2);ctx.fillStyle=colors[r.index];ctx.fill();ctx.lineWidth=2;ctx.strokeStyle="#fff";ctx.stroke();
  ctx.fillStyle="#fff";ctx.font="bold 11px sans-serif";ctx.fillText(r.name||"Coureur",x,y-15);
 });
 var sorted=valid.map(function(r){return Object.assign({},r,{km:distance*Math.min(1,elapsed/r.time),done:elapsed>=r.time});}).sort(function(a,b){return b.km-a.km||a.time-b.time;});
 $("c5-standing").innerHTML=sorted.length?'<h3>Classement en direct</h3><table><thead><tr><th>#</th><th>Coureur</th><th>Distance</th><th>Chrono</th><th>Statut</th></tr></thead><tbody>'+sorted.map(function(r,i){return "<tr><td>"+(i+1)+"</td><td>"+String(r.name||"Coureur").replace(/</g,"&lt;")+(r.official?"":" (manuel)")+"</td><td>"+r.km.toFixed(2)+" km</td><td>"+fmt(r.time)+"</td><td>"+(r.done?"Arrivé":"En course")+"</td></tr>";}).join("")+"</tbody></table>":"Ajoute jusqu'à cinq profils et leurs chronos.";
 $("c5-clock").textContent=fmt(elapsed);$("c5-slider").max=String(Math.max(1,...runners.map(function(r){return r.time||0;})));$("c5-slider").value=String(elapsed);
}
function loadRace(id){var race=getRace();if(!race)return;pause();results=[];elapsed=0;distance=Number(race.distance)||10;$("c5-distance").value=distance;$("c5-note").textContent=race.name+" · "+distance+" km — chargement des résultats officiels…";window.parent.postMessage({type:"elo-ghost-request-full-race",raceId:String(id)},"*");renderCards();draw();}
$("c5-race").addEventListener("change",function(e){loadRace(e.target.value);});
$("c5-distance").addEventListener("change",function(e){var v=Number(e.target.value);if(v>0&&v<=200){distance=v;elapsed=0;draw();}});
$("c5-add").addEventListener("click",function(){if(runners.length<5){runners.push({name:"",id:null,time:0,manual:"",official:false});renderCards();draw();}});
$("c5-runners").addEventListener("change",function(e){
 var i=Number(e.target.dataset.runner);if(e.target.dataset.runner!==undefined){var p=getPerson(e.target.value);runners[i].name=p?p.name:e.target.value;runners[i].id=p?p.id:null;applyTimes();renderCards();draw();return;}
 i=Number(e.target.dataset.manual);if(e.target.dataset.manual!==undefined){runners[i].manual=e.target.value;applyTimes();renderCards();draw();}
});
$("c5-runners").addEventListener("input",function(e){if(e.target.dataset.manual!==undefined){var i=Number(e.target.dataset.manual);runners[i].manual=e.target.value;applyTimes();draw();}});
$("c5-play").addEventListener("click",function(){if(playing){pause();return;}applyTimes();if(!runners.some(function(r){return r.time>0;})){$("c5-note").textContent="Choisis des coureurs et utilise les chronos officiels ou une saisie manuelle.";return;}var max=Math.max.apply(null,runners.map(function(r){return r.time||0;}));if(elapsed>=max)elapsed=0;playing=true;last=0;$("c5-play").textContent="Ⅱ Pause";raf=requestAnimationFrame(tick);});
function tick(t){if(!playing)return;if(last)elapsed+=(t-last)/1000*speed;last=t;var max=Math.max(1,...runners.map(function(r){return r.time||0;}));if(elapsed>=max){elapsed=max;pause();}draw();if(playing)raf=requestAnimationFrame(tick);}
$("c5-reset").addEventListener("click",function(){pause();elapsed=0;draw();});
$("c5-speed").addEventListener("change",function(e){speed=Number(e.target.value)||1;});
$("c5-slider").addEventListener("input",function(e){pause();elapsed=Number(e.target.value)||0;draw();});
window.addEventListener("message",function(e){
 if(e.source!==window.parent||!e.data)return;
 if(e.data.type==="elo-ghost-runner-directory"){people=Array.isArray(e.data.runners)?e.data.runners:[];var dl=document.getElementById("c5-directory");if(!dl){dl=document.createElement("datalist");dl.id="c5-directory";document.body.appendChild(dl);}dl.innerHTML=people.map(function(p){var op=document.createElement("option");op.value=p.name||"";return op.outerHTML;}).join("");if(!runners.length){runners=[{name:"",id:null,time:0,manual:"",official:false}];renderCards();}}
 if(e.data.type==="elo-ghost-race-directory"){races=Array.isArray(e.data.races)?e.data.races:[];$("c5-race").innerHTML='<option value="">Choisir une course réelle</option>'+races.map(function(r){return '<option value="'+String(r.id).replace(/"/g,"")+'">'+String(r.name).replace(/</g,"&lt;")+' · '+r.distance+' km</option>';}).join("");}
 if(e.data.type==="elo-ghost-full-race-data"){results=Array.isArray(e.data.results)?e.data.results:[];applyTimes();$("c5-note").textContent=results.length+" résultats réels reçus. Les coureurs absents peuvent avoir un chrono saisi manuellement.";renderCards();draw();}
});
window.addEventListener("resize",draw);
window.addEventListener("load",function(){window.parent.postMessage({type:"elo-ghost-request-directory"},"*");draw();});
})();