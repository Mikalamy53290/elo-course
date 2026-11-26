const SITE = "https://elo-course.eu";
const SUPABASE_URL = "https://gkxsxaeexbxyswlsftsz.supabase.co";
const SUPABASE_KEY = "sb_publishable_jiboviI5BaRii9_Lz9JK_A_qwXsVC-O";

const esc = (v) => String(v ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const slug = (v) => String(v ?? "fiche").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 70) || "fiche";
const validName = (v) => {
  const n = String(v ?? "").trim();
  if (!n) return false;
  const x = n.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
  return !/(^|\s)(xxx+|anonyme|anonymous|inconnu|inconnue|masked)(\s|$)/.test(x);
};
const profilePath = r => "/coureur/" + slug(r.name) + "--" + encodeURIComponent(String(r.id));
const racePath = r => "/course/" + slug(r.name) + "--" + encodeURIComponent(String(r.id));
const fmtTime = value => {
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) return "";
  const h = Math.floor(n / 3600), m = Math.floor(n % 3600 / 60), s = Math.round(n % 60);
  return (h ? h + ":" + String(m).padStart(2,"0") : String(m)) + ":" + String(s).padStart(2,"0");
};
const dateFR = value => {
  if (!value) return "";
  const d = new Date(String(value).slice(0,10) + "T12:00:00");
  return Number.isNaN(d.getTime()) ? "" : new Intl.DateTimeFormat("fr-FR",{day:"numeric",month:"long",year:"numeric"}).format(d);
};
function layout({title,description,canonical,body,robots="index,follow"}) {
  return `<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)}</title><meta name="description" content="${esc(description)}"><meta name="robots" content="${robots}">
<link rel="canonical" href="${esc(canonical)}"><meta property="og:type" content="website"><meta property="og:site_name" content="ELO COURSE"><meta property="og:title" content="${esc(title)}"><meta property="og:description" content="${esc(description)}"><meta property="og:url" content="${esc(canonical)}">
<style>body{margin:0;background:#0b1724;color:#f1f5f9;font:16px/1.6 system-ui,-apple-system,Segoe UI,sans-serif}main{max-width:900px;margin:auto;padding:28px 18px 60px}a{color:#7dd3fc}header{border-bottom:1px solid #294155;padding:16px 18px}header a{font-weight:800;text-decoration:none;color:#fff}h1{line-height:1.2;font-size:clamp(1.8rem,5vw,2.8rem)}.muted{color:#b8c7d6}.panel{background:#172b3d;border:1px solid #294155;border-radius:14px;padding:16px;margin:16px 0}.stats{display:flex;flex-wrap:wrap;gap:10px}.stat{background:#1b3348;border-radius:10px;padding:12px 16px}.stat strong{display:block;font-size:1.3rem}.list{padding-left:20px}.list li{margin:8px 0}.cta{display:inline-block;background:#ef8618;color:#111827;text-decoration:none;font-weight:800;padding:10px 16px;border-radius:9px;margin:8px 8px 8px 0}footer{border-top:1px solid #294155;margin-top:30px;padding-top:18px;font-size:.9rem;color:#b8c7d6}</style></head><body><header><a href="/">ELO COURSE</a> <span class="muted">· Sarthe · Mayenne · Maine-et-Loire</span></header><main>${body}<footer>Résultats issus des classements publics des courses. Pour demander la correction ou le retrait d’une fiche, consultez notre <a href="/confidentialite.html">page de confidentialité</a>.<br><a href="/confidentialite.html">Confidentialité</a> · <a href="/cgu.html">Conditions d’utilisation</a> · <a href="/mentions-legales.html">Mentions légales</a></footer></main></body></html>`;
}
async function getData(env) {
  const url = SUPABASE_URL + "/rest/v1/site_data?select=data&id=eq.1";
  const response = await fetch(url,{headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY}});
  if (!response.ok) throw new Error("Supabase HTTP " + response.status);
  const rows = await response.json();
  const data = rows?.[0]?.data;
  if (!data || !Array.isArray(data.runners) || !Array.isArray(data.races)) throw new Error("Données publiques indisponibles");
  return data;
}
async function getConsentIds() {
  try {
    const response = await fetch(SUPABASE_URL + "/rest/v1/rpc/elo_seo_public_runner_ids", {
      method:"POST",
      headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY,"content-type":"application/json"},
      body:"{}"
    });
    if (!response.ok) return new Set();
    const rows = await response.json();
    return new Set((Array.isArray(rows)?rows:[]).map(row=>String(row?.runner_id ?? row)).filter(Boolean));
  } catch (_) { return new Set(); }
}
function parseId(path, prefix) {
  const rest = path.slice(prefix.length).replace(/\/$/,"");
  const cut = rest.lastIndexOf("--");
  if (cut < 0) return decodeURIComponent(rest);
  return decodeURIComponent(rest.slice(cut + 2));
}
function publicRunners(data) {
  const used = new Set();
  for (const race of data.races) for (const result of (race.results || [])) if (!result.pending && result.id != null) used.add(String(result.id));
  return (data.runners || []).filter(r => r && r.id != null && used.has(String(r.id)) && validName(r.name));
}
function consentedRunners(data, consentedIds) {
  // L’indexation nominative est conditionnée à un compte approuvé et à un accord explicite.
  return publicRunners(data).filter(r => consentedIds.has(String(r.id)));
}
async function getSections(env) {
  try {
    const asset = await env.ASSETS.fetch(new Request(SITE + "/"));
    if (!asset.ok) return [];
    const html = await asset.text();
    const found = [], seen = new Set();
    const buttons = html.matchAll(/<button\b([^>]*)>([\s\S]*?)<\/button>/gi);
    const privateViews = new Set(["me","organizer"]);
    for (const match of buttons) {
      const attrs = match[1], inner = match[2];
      if (!/data-act=["']view["']/.test(attrs)) continue;
      const viewMatch = attrs.match(/data-v=["']([^"']+)["']/);
      if (!viewMatch) continue;
      const view = viewMatch[1];
      if (privateViews.has(view) || view === "upcoming" || seen.has(view)) continue;
      seen.add(view);
      const fullLabel = inner.match(/<span[^>]*class=["'][^"']*full[^"']*["'][^>]*>([\s\S]*?)<\/span>/i);
      const label = String((fullLabel ? fullLabel[1] : inner).replace(/<[^>]*>/g," ").replace(/&amp;/g,"&").replace(/\s+/g," ").trim() || view);
      if (view === "accueil") continue;
      found.push({view,label,path:"/rubrique/"+slug(label)});
    }
    return found;
  } catch (_) { return []; }
}
async function sitemap(data, consentedIds, sections) {
  const runners = consentedRunners(data, consentedIds);
  const today = new Intl.DateTimeFormat("fr-CA",{timeZone:"Europe/Paris"}).format(new Date());
  const races = (data.races || []).filter(r => r && r.id != null && (
    (r.results || []).some(x => !x.pending) ||
    (r.date && String(r.date).slice(0,10) >= today)
  ));
  const fixed = ["/","/courses-a-venir","/boutique.html","/training.html"];
  const urls = fixed.map(p => `<url><loc>${SITE+p}</loc></url>`);
  for (const section of sections) urls.push(`<url><loc>${SITE+section.path}</loc></url>`);
  for (const r of runners) urls.push(`<url><loc>${esc(SITE+profilePath(r))}</loc></url>`);
  for (const r of races) urls.push(`<url><loc>${esc(SITE+racePath(r))}</loc></url>`);
  return `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${urls.join("")}</urlset>`;
}
async function routeSEO(request, env) {
  const url = new URL(request.url), path = decodeURI(url.pathname);
  if (path === "/robots.txt") return new Response("User-agent: *\nAllow: /\nDisallow: /admin\nDisallow: /compte\n\nUser-agent: OAI-SearchBot\nAllow: /\nDisallow: /admin\nDisallow: /compte\n\nUser-agent: PerplexityBot\nAllow: /\nDisallow: /admin\nDisallow: /compte\n\nUser-agent: ClaudeBot\nAllow: /\nDisallow: /admin\nDisallow: /compte\n\nUser-agent: Claude-SearchBot\nAllow: /\nDisallow: /admin\nDisallow: /compte\n\nSitemap: "+SITE+"/sitemap.xml\n",{headers:{"content-type":"text/plain; charset=utf-8","cache-control":"public, max-age=3600"}});
  if (path === "/sitemap.xml") {
    try {
      const data=await getData(env);
      const consentedIds=await getConsentIds();
      const sections=await getSections(env);
      return new Response(await sitemap(data,consentedIds,sections),{headers:{"content-type":"application/xml; charset=utf-8","cache-control":"public, max-age=300"}});
    } catch(e) {
      // En cas d'indisponibilité temporaire de Supabase, ne pas renvoyer une erreur 503 à Google.
      // On sert le sitemap statique de secours depuis les assets, puis un sitemap minimal si nécessaire.
      try {
        const fallback=await env.ASSETS.fetch(new Request(new URL("/sitemap.xml",url)));
        if(fallback.ok) return new Response(fallback.body,{status:200,headers:{"content-type":"application/xml; charset=utf-8","cache-control":"public, max-age=300"}});
      } catch(_) {}
      const minimal='<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc>'+SITE+'/</loc></url></urlset>';
      return new Response(minimal,{status:200,headers:{"content-type":"application/xml; charset=utf-8","cache-control":"public, max-age=300"}});
    }
  }
  if (path === "/courses-a-venir") {
    try {
      const data = await getData(env);
      const today = new Intl.DateTimeFormat("fr-CA",{timeZone:"Europe/Paris"}).format(new Date());
      const upcoming = (data.races || []).filter(r => r && r.id != null && r.date && String(r.date).slice(0,10) >= today)
        .sort((a,b)=>String(a.date).localeCompare(String(b.date)));
      const items = upcoming.map(r => `<li><strong><a href="${esc(SITE+racePath(r))}">${esc(r.name||"Course à venir")}</a></strong> · ${esc(dateFR(r.date))} · ${esc(r.dist||"Distance à préciser")} · ${esc(r.department||r.departement||"Sarthe, Mayenne ou Maine-et-Loire")}</li>`).join("");
      const body = `<h1>Courses à venir en Sarthe, Mayenne et Maine-et-Loire</h1><p>Retrouvez le calendrier des prochaines courses sur route et courses nature référencées par ELO COURSE dans les départements 72, 53 et 49. Les dates, distances et lieux sont ceux enregistrés dans le calendrier du site.</p><section class="panel"><h2>Prochaines épreuves</h2>${upcoming.length ? '<ol class="list">'+items+'</ol>' : '<p>Aucune course future n’est actuellement publiée dans le calendrier. Consultez à nouveau cette page pour les prochaines mises à jour.</p>'}</section><a class="cta" href="/?view=upcoming">Ouvrir le calendrier dans ELO COURSE</a><a href="/">Retour à l’accueil</a>`;
      return new Response(layout({title:"Courses à venir – Calendrier des courses | ELO COURSE",description:"Calendrier des prochaines courses sur route et courses nature en Sarthe (72), Mayenne (53) et Maine-et-Loire (49). Dates, distances et résultats sur ELO COURSE.",canonical:SITE+"/courses-a-venir",body}),{headers:{"content-type":"text/html; charset=utf-8","cache-control":"public, max-age=300"}});
    } catch(e) {
      return new Response(layout({title:"Courses à venir | ELO COURSE",description:"Calendrier des prochaines courses en Sarthe, Mayenne et Maine-et-Loire.",canonical:SITE+"/courses-a-venir",body:"<h1>Courses à venir</h1><p>Le calendrier est momentanément indisponible. Réessayez dans quelques instants.</p>"}),{status:503,headers:{"content-type":"text/html; charset=utf-8","retry-after":"60"}});
    }
  }
  const sections = path.startsWith("/rubrique/") ? await getSections(env) : [];
  const section = sections.find(item => item.path === path);
  if (section) {
    const copyByView = {
      rank:["Classement ELO des coureurs","Le classement ELO d’ELO COURSE compare les performances des coureurs à partir des résultats de courses publiés. Retrouvez les classements généraux et par catégorie."],
      races:["Résultats des courses","ELO COURSE rassemble les résultats des courses sur route et des courses nature, avec les classements et les chronos publiés par les organisateurs et chronométreurs."],
      ghost:["Mode Ghost – simulation ELO","Le Mode Ghost permet d’explorer et de simuler l’évolution du classement ELO à partir des performances de course."],
      chrono:["Chronométreurs et résultats de course","ELO COURSE référence les résultats publiés par les chronométreurs et organisateurs de courses, notamment pour les épreuves en Sarthe, Mayenne et Maine-et-Loire."],
      help:["Règlement ELO COURSE","Présentation du fonctionnement du classement ELO COURSE, des profils coureurs et des résultats publiés."]
    };
    const known = copyByView[section.view] || ["Rubrique "+section.label,"Retrouvez cette rubrique publique du site ELO COURSE, consacré aux classements et aux résultats de course à pied en Sarthe, Mayenne et Maine-et-Loire."];
    const title = known[0];
    const description = known[1];
    const details = section.view === "rank"
      ? `<section class="panel"><h2>Les classements disponibles</h2><p>Les classements ELO sont organisés par discipline et par territoire : courses sur route et courses nature, Sarthe (72), Mayenne (53), Maine-et-Loire (49), ainsi que des classements généraux. Les vues par sexe et par catégorie permettent de situer les performances de chaque coureur.</p><a class="cta" href="/?view=rank">Consulter les classements ELO</a></section>`
      : section.view === "races"
      ? `<section class="panel"><h2>Résultats et chronos</h2><p>Les fiches de courses présentent les épreuves terminées, les classements d’arrivée et les chronos disponibles. Les résultats publiés alimentent les classements ELO des coureurs.</p><a class="cta" href="/?view=races">Consulter les résultats des courses</a><a class="cta" href="/courses-a-venir">Découvrir les courses à venir</a></section>`
      : `<a class="cta" href="/?view=${encodeURIComponent(section.view)}">Ouvrir cette rubrique dans ELO COURSE</a>`;
    return new Response(layout({title,description,canonical:SITE+section.path,body:`<h1>${esc(title)}</h1><p>${esc(description)}</p><p>Le site couvre la Sarthe, la Mayenne et le Maine-et-Loire.</p>${details}`}),{headers:{"content-type":"text/html; charset=utf-8","cache-control":"public, max-age=300"}});
  }
  if (!path.startsWith("/coureur/") && !path.startsWith("/course/")) return null;
  let data;
  try { data=await getData(env); } catch(e) { return new Response("Fiche momentanément indisponible. Réessayez dans quelques instants.",{status:503,headers:{"content-type":"text/plain; charset=utf-8","retry-after":"60"}}); }
  if (path.startsWith("/coureur/")) {
    const id=parseId(path,"/coureur/");
    const runner=publicRunners(data).find(r=>String(r.id)===id);
    const consentedIds=await getConsentIds();
    if (!runner || !consentedIds.has(String(runner.id))) return new Response("Cette fiche coureur n’est pas publiée.",{status:404,headers:{"content-type":"text/plain; charset=utf-8","x-robots-tag":"noindex","cache-control":"no-store"}});
    const results=[];
    for (const race of data.races || []) for (const item of race.results || []) if (!item.pending && String(item.id)===id) results.push({race,item});
    results.sort((a,b)=>String(b.race.date||"").localeCompare(String(a.race.date||"")));
    const latest=results.slice(0,30);
    const title=runner.name+" – Profil coureur ELO COURSE";
    const description="Retrouvez les résultats de "+runner.name+" en course à pied en Sarthe, Mayenne et Maine-et-Loire sur ELO COURSE.";
    const body=`<h1>${esc(runner.name)}</h1><p class="muted">Profil coureur · ELO COURSE</p><div class="stats"><div class="stat"><strong>${results.length}</strong>course(s) classée(s)</div></div><section class="panel"><h2>Résultats de course</h2>${latest.length?'<ol class="list">'+latest.map(({race,item})=>'<li><strong>'+esc(race.name||"Course")+'</strong> · '+esc(dateFR(race.date))+' · '+esc(race.dist||"Distance non précisée")+(item.rk?' · '+esc(item.rk)+'e':'')+(fmtTime(item.time)?' · '+esc(fmtTime(item.time)):'')+'</li>').join("")+'</ol>':'<p>Aucun résultat détaillé disponible.</p>'}${results.length>30?'<p class="muted">Les 30 résultats les plus récents sont affichés sur cette page.</p>':''}</section><a class="cta" href="/#profil=${encodeURIComponent(String(runner.id))}">Ouvrir le profil dans ELO COURSE</a><a href="/">Retour au site</a>`;
    return new Response(layout({title,description,canonical:SITE+profilePath(runner),body,robots:"index,follow"}),{headers:{"content-type":"text/html; charset=utf-8","cache-control":"public, max-age=300"}});
  }
  const id=parseId(path,"/course/");
  const race=(data.races||[]).find(r=>String(r.id)===id);
  const today = new Intl.DateTimeFormat("fr-CA",{timeZone:"Europe/Paris"}).format(new Date());
  const hasResults = !!(race && (race.results||[]).some(x=>!x.pending));
  const isUpcoming = !!(race && race.date && String(race.date).slice(0,10) >= today);
  if (!race || (!hasResults && !isUpcoming)) return new Response("Course introuvable",{status:404,headers:{"content-type":"text/plain; charset=utf-8","x-robots-tag":"noindex"}});
  const consentedIds=await getConsentIds();
  const byId=new Map(consentedRunners(data,consentedIds).map(r=>[String(r.id),r]));
  const results=(race.results||[]).filter(x=>!x.pending).slice().sort((a,b)=>(Number(a.rk)||999999)-(Number(b.rk)||999999));
  const raceYear=race.date?String(race.date).slice(0,4):"";
  const title=isUpcoming ? (race.name||"Course")+" – Course à venir"+(raceYear?" "+raceYear:"")+" | ELO COURSE" : (race.name||"Course")+" – Résultats"+(raceYear?" "+raceYear:"")+" | ELO COURSE";
  const description=isUpcoming
    ? "Course à venir : "+(race.name||"épreuve")+" · "+(race.dist||"course à pied")+" · "+dateFR(race.date)+". Calendrier des courses en Sarthe, Mayenne et Maine-et-Loire sur ELO COURSE."
    : "Résultats de "+(race.name||"cette course")+" · "+(race.dist||"course à pied")+" · "+dateFR(race.date)+". Consultez le classement sur ELO COURSE.";
  const resultList=results.slice(0,50).map(x=>{const r=byId.get(String(x.id));return '<li>'+ (x.rk?'<strong>'+esc(x.rk)+'e</strong> · ':'')+(r?'<a href="'+esc(SITE+profilePath(r))+'">'+esc(r.name)+'</a>':"Coureur")+(fmtTime(x.time)?' · '+esc(fmtTime(x.time)):'')+'</li>';}).join("");
  const body=isUpcoming
    ? `<h1>${esc(race.name||"Course à venir")}</h1><p class="muted">${esc(dateFR(race.date))} · ${esc(race.dist||"Distance non précisée")} · ${esc(race.department||race.departement||"Sarthe, Mayenne ou Maine-et-Loire")}</p><p>Cette épreuve figure au calendrier public d’ELO COURSE. Retrouvez les informations disponibles sur sa date, sa distance et son territoire. Les résultats seront affichés lorsqu’ils auront été publiés et intégrés au classement.</p><a class="cta" href="/courses-a-venir">Voir toutes les courses à venir</a><a href="/">Retour au site</a>`
    : `<h1>${esc(race.name||"Course")}</h1><p class="muted">${esc(dateFR(race.date))} · ${esc(race.dist||"Distance non précisée")} · ${esc(race.department||race.departement||"Sarthe, Mayenne ou Maine-et-Loire")}</p><div class="stats"><div class="stat"><strong>${results.length}</strong>résultats publiés</div></div><section class="panel"><h2>Classement de la course</h2><ol class="list">${resultList}</ol>${results.length>50?'<p class="muted">Les 50 premiers résultats sont affichés ici. Tous les résultats sont consultables sur le site.</p>':''}</section><a class="cta" href="/?course=${encodeURIComponent(String(race.id))}">Voir tous les résultats sur ELO COURSE</a><a href="/">Retour au site</a>`;
  return new Response(layout({title,description,canonical:SITE+racePath(race),body}),{headers:{"content-type":"text/html; charset=utf-8","cache-control":"public, max-age=300"}});
}
export default {
  async fetch(request, env) {
    const url=new URL(request.url);
    if (request.method!=="GET" && request.method!=="HEAD") return env.ASSETS.fetch(request);
    const response=await routeSEO(request,env);
    if (response) return request.method==="HEAD" ? new Response(null,{status:response.status,statusText:response.statusText,headers:response.headers}) : response;
    const assetResponse=await env.ASSETS.fetch(request);
    // Les liens de partage et de parrainage utilisent des paramètres sur l’accueil.
    // Les pages canoniques propres (/course/..., /coureur/...) restent indexables.
    if (url.pathname==="/" && url.search) {
      const headers=new Headers(assetResponse.headers);
      headers.set("x-robots-tag","noindex, follow");
      return new Response(assetResponse.body,{status:assetResponse.status,statusText:assetResponse.statusText,headers});
    }
    return assetResponse;
  }
};
