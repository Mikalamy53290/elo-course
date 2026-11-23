/* ELO COURSE — Bandeau d'annonces administrable */
(function(){
  "use strict";
  var URL="https://gkxsxaeexbxyswlsftsz.supabase.co";
  var KEY="sb_publishable_jiboviI5BaRii9_Lz9JK_A_qwXsVC-O";
  var ADMIN="26789cc4-2ac3-4129-95c8-2234b1dc748d";
  if(!window.supabase || !window.supabase.createClient) return;
  var db=window.supabase.createClient(URL,KEY,{auth:{storageKey:"sb-gkxsxaeexbxyswlsftsz-auth-token",persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
  var bar, panel, input, status, bodyObserver;
  var lastMessage=null, lastActive=null, refreshBusy=false, adminBusy=false;
  var style=document.createElement("style");
  style.textContent="#elo-announcement{position:sticky;top:0;z-index:99999;display:none;overflow:hidden;background:linear-gradient(90deg,#101d35,#193b63);color:#fff;border-bottom:2px solid #d7ad52;padding:10px 0;font-weight:700;font-size:14px;min-height:40px}#elo-announcement .elo-track{display:flex;width:max-content;white-space:nowrap;animation:elo-scroll 24s linear infinite}#elo-announcement .elo-item{padding-right:80px}#elo-announcement:hover .elo-track,#elo-announcement:focus-within .elo-track{animation-play-state:paused}@keyframes elo-scroll{from{transform:translateX(100vw)}to{transform:translateX(-100%)}}@media(prefers-reduced-motion:reduce){#elo-announcement .elo-track{animation:none;width:auto;justify-content:center;white-space:normal;padding:0 16px}}#elo-announcement-admin{margin:18px 0;padding:16px;border:1px solid #d7ad52;border-radius:14px;background:rgba(20,35,58,.06);position:relative;z-index:2}#elo-announcement-admin textarea{box-sizing:border-box;width:100%;min-height:84px;padding:10px;border:1px solid #aab4c2;border-radius:8px;font:inherit}#elo-announcement-admin button{margin:8px 8px 0 0;padding:9px 13px;border:0;border-radius:8px;background:#193b63;color:white;font-weight:700}#elo-announcement-admin button.stop{background:#8d3030}#elo-announcement-admin small{display:block;margin-top:8px}";
  document.head.appendChild(style);
  function makeBar(){
    if(!document.body)return null;
    var existing=document.getElementById("elo-announcement");
    if(existing){bar=existing;return bar;}
    bar=document.createElement("div");bar.id="elo-announcement";bar.setAttribute("role","status");bar.setAttribute("aria-live","polite");
    var track=document.createElement("div");track.className="elo-track";var item=document.createElement("span");item.className="elo-item";track.appendChild(item);bar.appendChild(track);
    document.body.insertBefore(bar,document.body.firstChild);
    return bar;
  }
  function render(row){
    var node=makeBar();if(!node)return;
    var active=!!(row&&row.active&&row.message&&String(row.message).trim());
    var message=active?String(row.message).trim():"";
    if(active!==lastActive||message!==lastMessage){
      node.firstChild.firstChild.textContent=active?(message+"　　"+message):"";
      node.style.display=active?"block":"none";
      lastActive=active;lastMessage=message;
    }
  }
  async function refresh(){
    if(refreshBusy)return;refreshBusy=true;
    try{
      var r=await db.from("site_announcements").select("message,active,updated_at").eq("id",1).maybeSingle();
      if(r.error)throw r.error;
      render(r.data||{active:false,message:""});
      if(status)status.textContent=r.data&&r.data.active?"Annonce publiée et visible sur le site.":"Aucune annonce active.";
      if(input&&document.activeElement!==input&&r.data&&r.data.message)input.value=r.data.message;
    }catch(e){if(status)status.textContent="Lecture du bandeau impossible : "+(e.message||e);}
    finally{refreshBusy=false;}
  }
  async function checkAdmin(){
    if(adminBusy)return;adminBusy=true;
    try{
      var session=await db.auth.getSession();
      var user=session&&session.data&&session.data.session&&session.data.session.user;
      var host=document.getElementById("v-races");
      var ok=!!(user&&user.id===ADMIN);
      if(ok&&host)makePanel();
      else if(panel&&panel.parentNode)panel.parentNode.removeChild(panel);
    }catch(e){}
    finally{adminBusy=false;}
  }
  function makePanel(){
    var host=document.getElementById("v-races");
    if(!host)return;
    if(!panel){
      panel=document.createElement("section");panel.id="elo-announcement-admin";
      var h=document.createElement("h3");h.textContent="Bandeau défilant du site";panel.appendChild(h);
      var p=document.createElement("p");p.textContent="Le message ci-dessous défile en haut du site pour tous les visiteurs. Tu peux le modifier ou l’arrêter.";panel.appendChild(p);
      input=document.createElement("textarea");input.maxLength=500;input.placeholder="Écris ici le message à faire défiler…";input.setAttribute("aria-label","Texte du bandeau");panel.appendChild(input);
      var publish=document.createElement("button");publish.textContent="Publier / remplacer le bandeau";publish.addEventListener("click",publishMessage);panel.appendChild(publish);
      var stop=document.createElement("button");stop.className="stop";stop.textContent="Arrêter le bandeau";stop.addEventListener("click",stopMessage);panel.appendChild(stop);
      var reload=document.createElement("button");reload.textContent="Actualiser";reload.addEventListener("click",refresh);panel.appendChild(reload);
      status=document.createElement("small");panel.appendChild(status);
    }
    if(panel.parentNode!==host)host.insertBefore(panel,host.firstChild);
  }
  async function publishMessage(){
    var message=(input.value||"").trim();
    if(!message){status.textContent="Écris un message avant de publier.";return;}
    status.textContent="Publication…";
    var r=await db.from("site_announcements").upsert({id:1,message:message,active:true,updated_at:new Date().toISOString()},{onConflict:"id"});
    if(r.error){status.textContent="Erreur : "+r.error.message;return;}
    await refresh();
  }
  async function stopMessage(){
    status.textContent="Interruption…";
    var r=await db.from("site_announcements").upsert({id:1,message:"",active:false,updated_at:new Date().toISOString()},{onConflict:"id"});
    if(r.error){status.textContent="Erreur : "+r.error.message;return;}
    input.value="";await refresh();
  }
  async function checkAdmin(){
    if(adminBusy)return;adminBusy=true;
    try{
      var session=await db.auth.getSession();
      var user=session&&session.data&&session.data.session&&session.data.session.user;
      var host=document.getElementById("v-races");
      var ok=!!(user&&user.id===ADMIN);
      if(ok&&host)makePanel();
      else if(panel&&panel.parentNode)panel.parentNode.removeChild(panel);
    }catch(e){}
    finally{adminBusy=false;}
  }
  async function init(){
    if(!document.body){document.addEventListener("DOMContentLoaded",init,{once:true});return;}
    makeBar();
    await refresh();
    await checkAdmin();
    db.auth.onAuthStateChange(function(){checkAdmin();});
    if(window.MutationObserver&&!bodyObserver){
      bodyObserver=new MutationObserver(function(){
        makeBar();
        if(!document.getElementById("elo-announcement-admin"))checkAdmin();
      });
      bodyObserver.observe(document.body,{childList:true,subtree:true});
    }
    setInterval(refresh,10000);
    setInterval(checkAdmin,1500);
  }
  if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",init);else init();
})();