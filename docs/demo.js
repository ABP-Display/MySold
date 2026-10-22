'use strict';

// All records below are fictional. State lives only in this page's memory.
const icons = {month:0xf051f,stats:0xf00ce,global:0xefa1,person:0xe497,left:0xe5cb,right:0xe5cc,income:0xf575,expense:0xf57e,investment:0xf00ce,remaining:0xf336,transfer:0xf01fa,bank:0xee32,category:0xef37,alerts:0xf235,pdf:0xf2a4,settings:0xf36e,search:0xf013d,lock:0xe3b1,savings:0xf336,home:0xf107,shopping:0xf37f,car:0xefc6,health:0xe25c,other:0xe402};
const icon = name => `<span class="mi" aria-hidden="true">&#${icons[name] || icons.other};</span>`;
const months = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre'];
const shortMonths = ['janv.','févr.','mars','avr.','mai','juin','juil.','août','sept.','oct.','nov.','déc.'];
const annual = {income:Array(10).fill(3200),expense:[1720,1810,1940,1690,1820,2260,2100,1730,1900,1850],investment:Array(10).fill(450)};
const accounts = [
  {name:'Compte courant',description:'Compte bancaire personnel',balance:2450,icon:'bank'},
  {name:'Livret d’épargne',description:'Épargne disponible',balance:8200,icon:'savings'},
  {name:'Compte titres',description:'Géré par les investissements',balance:11350,icon:'investment'}
];
const assets = [{name:'ETF Monde',kind:'ETF',balance:7200},{name:'Or',kind:'Autres',balance:2350},{name:'Bitcoin',kind:'Crypto',balance:1800}];
const expenseCategories = [
  {name:'Logement',description:'Loyer',amount:900,icon:'home',color:'var(--red)'},
  {name:'Alimentation',description:'Courses du quotidien',amount:310,icon:'shopping',color:'var(--amber)'},
  {name:'Transport',description:'Abonnement et carburant',amount:145,icon:'car',color:'var(--teal)'},
  {name:'Loisirs',description:'Sorties et activités',amount:220,icon:'category',color:'#b58fda'},
  {name:'Santé',description:'Pharmacie et soins',amount:95,icon:'health',color:'var(--green)'},
  {name:'Autres',description:'Achats divers',amount:180,icon:'other',color:'var(--neutral)'}
];
const incomeCategories = [{name:'Salaire',description:'Salaire mensuel',amount:3000,color:'var(--green)'},{name:'Remboursements',description:'Remboursement de frais',amount:125,color:'var(--teal)'},{name:'Ventes',description:'Vente d’occasion',amount:75,color:'var(--amber)'}];
const investmentCategories = [{name:'ETF Monde',description:'Versement ETF Monde',amount:300,color:'var(--neutral)'},{name:'Or',description:'Achat d’or',amount:100,color:'var(--amber)'},{name:'Bitcoin',description:'Versement crypto',amount:50,color:'var(--teal)'}];
const types = {expense:{label:'Dépenses',color:'var(--red)',sign:'−'},income:{label:'Revenus',color:'var(--green)',sign:'+'},investment:{label:'Investissements',color:'var(--neutral)',sign:''},transfer:{label:'Transferts',color:'var(--teal)',sign:''}};
const views = ['mois','stats','global','profil'];
const state = {view:'mois',month:9,type:'expense',private:false,light:false,search:'',series:new Set(['income','expense','investment','remaining'])};
const content = document.getElementById('content');
const dialog = document.getElementById('detail');
const euro = new Intl.NumberFormat('fr-FR',{style:'currency',currency:'EUR'});
const money = n => state.private ? '**** €' : euro.format(n);
const compact = n => state.private ? '****' : `${new Intl.NumberFormat('fr-FR',{maximumFractionDigits:1}).format(n/1000)} k€`;
const percent = n => state.private ? '** %' : `${n.toFixed(1).replace('.',',')} %`;
const total = values => values.reduce((a,b)=>a+b,0);
const remainder = month => annual.income[month]-annual.expense[month]-annual.investment[month];
const period = () => `${months[state.month]} 2026`;
const tint = type => types[type]?.color || 'var(--text)';
const detailsFootnote = '<p class="dialog-footnote">Exemple fictif · aucune opération enregistrée.</p>';

function metric(label,value,type){
  return `<article class="metric ${type}"><div class="metric-icon">${icon(type)}</div><div><span class="metric-label">${label}</span><strong class="${type==='income'?'green':type==='expense'?'red':''}">${money(value)}</strong></div></article>`;
}
function transactionData(){
  let categories;
  if(state.type==='expense'){
    let allocated=0;
    categories=expenseCategories.map((item,i)=>{
      const amount=i===expenseCategories.length-1 ? +(annual.expense[state.month]-allocated).toFixed(2) : +(item.amount*annual.expense[state.month]/1850).toFixed(2);
      allocated+=amount;
      return {...item,amount};
    });
  } else if(state.type==='income') categories=incomeCategories;
  else if(state.type==='investment') categories=investmentCategories;
  else categories=[{name:'Épargne',description:'Virement vers le livret',amount:250,color:'var(--teal)'}];
  return categories.map((item,i)=>({...item,day:[1,22,12,15,8,19][i],account:state.type==='transfer'?'Compte courant → Livret d’épargne':state.type==='investment'?'Compte courant → Compte titres':'Compte courant'}));
}
function monthGraph(rows){
  if(state.private) return mask();
  if(state.type==='income'){
    let offset=0;
    const sum=total(rows.map(r=>r.amount));
    const circles=rows.map(r=>{
      const length=r.amount/sum*100;
      const result=`<circle cx="100" cy="100" r="72" fill="none" stroke="${r.color}" stroke-width="40" pathLength="100" stroke-dasharray="${length} ${100-length}" stroke-dashoffset="${-offset}" transform="rotate(-90 100 100)"/>`;
      offset+=length;return result;
    }).join('');
    return `<div class="donut-layout"><svg class="donut" viewBox="0 0 200 200" role="img" aria-label="Répartition des revenus fictifs"><title>Revenus : salaire, remboursements et ventes</title>${circles}<text x="100" y="97" text-anchor="middle" class="axis-label">Revenus</text><text x="100" y="119" text-anchor="middle" class="chart-value">${money(sum)}</text></svg><div class="donut-labels">${rows.map(r=>`<div class="donut-item"><span class="legend-dot" style="background:${r.color}"></span><span>${r.name}</span><strong>${money(r.amount)}</strong></div>`).join('')}</div></div>`;
  }
  const maximum=Math.max(...rows.map(r=>r.amount));
  return `<div class="month-graph" role="img" aria-label="Répartition par catégorie de ${types[state.type].label.toLowerCase()}">${rows.map(r=>`<div class="month-bar"><span class="month-bar-amount">${money(r.amount)}</span><div class="month-bar-track"><div class="month-bar-fill" style="--height:${r.amount/maximum*100}%;--bar:${r.color}"></div></div><span class="month-bar-label" title="${r.name}">${r.name}</span></div>`).join('')}</div>`;
}
function renderMonth(){
  const rows=transactionData();
  const sum=total(rows.map(r=>r.amount));
  return `<div class="month-wrap"><div class="period"><button class="icon-button" data-month="-1" aria-label="Mois précédent" title="Mois précédent" ${state.month===0?'disabled':''}>${icon('left')}</button><h1>${period()}</h1><button class="icon-button" data-month="1" aria-label="Mois suivant" title="Mois suivant" ${state.month===9?'disabled':''}>${icon('right')}</button></div>${monthGraph(rows)}<label class="search">${icon('search')}<input id="search" type="search" placeholder="Rechercher une transaction" aria-label="Rechercher parmi les transactions fictives" autocomplete="off" spellcheck="false"></label><div class="transactions-head"><h2>Transactions mensuelles (${rows.length})</h2><strong style="color:${tint(state.type)}">${state.private?'':types[state.type].sign}${money(sum)}</strong></div><div id="transactions" class="transactions"></div><nav class="type-nav" aria-label="Type de transactions">${Object.entries(types).map(([key,value])=>`<button data-type="${key}" aria-label="${value.label}" aria-pressed="${state.type===key}">${icon(key)}${key==='investment'?'Placements':value.label}</button>`).join('')}</nav></div>`;
}
function renderTransactions(){
  const container=document.getElementById('transactions');
  if(!container) return;
  const rows=transactionData().map((r,index)=>({...r,index})).filter(r=>`${r.description} ${r.name} ${r.account}`.toLocaleLowerCase('fr').includes(state.search.toLocaleLowerCase('fr')));
  container.innerHTML=rows.length ? rows.map(r=>`<button class="transaction" data-transaction="${r.index}" style="--tint:${tint(state.type)}"><span class="mi" aria-hidden="true">&#${icons[r.icon]||icons[state.type]};</span><span class="row-main"><strong>${r.description}</strong><small>${r.account} · ${r.name} · ${String(r.day).padStart(2,'0')}/${String(state.month+1).padStart(2,'0')}/2026</small></span><span class="row-amount">${state.private?'':types[state.type].sign}${money(r.amount)}</span></button>`).join('') : '<p class="empty">Aucune transaction correspondante.</p>';
}
function mask(){return `<div class="chart-mask">${icon('lock')}<span>Montants masqués</span></div>`;}
function wealthChart(){
  if(state.private)return mask();
  const w=760,h=250,left=60,right=16,top=18,bottom=30,min=7000,max=27000;
  const x=n=>left+n/12*(w-left-right),y=n=>h-bottom-(n-min)/(max-min)*(h-top-bottom);
  const values=[8820,10300,11690,12950,14460,15840,16780,17880,19350,20650,22000];
  const points=values.map((v,i)=>[x(i===10?9.7:i),y(v)]);
  const real='M'+points.map(p=>p.join(',')).join(' L');
  const future=[[9.7,22000],[9.95,21910],[10.15,22250],[10.4,22080],[10.65,22850],[10.9,22750],[11.15,23420],[11.4,23200],[11.7,23960],[12,24500]];
  const projection='M'+future.map(([a,b])=>`${x(a)},${y(b)}`).join(' L');
  return `<div class="plot-scroll"><svg width="760" height="250" viewBox="0 0 ${w} ${h}" role="img" aria-label="Évolution fictive du patrimoine et projection jusqu’à décembre"><title>Patrimoine de 8 820 € en janvier à 22 000 € en octobre ; projection illustrative jusqu’à décembre.</title>${[8000,12000,16000,20000,24000].map(v=>`<line x1="${left}" y1="${y(v)}" x2="${w-right}" y2="${y(v)}" class="chart-grid"/><text x="${left-10}" y="${y(v)+4}" text-anchor="end" class="axis-label">${compact(v)}</text>`).join('')}<path d="${real} L${x(9.7)},${h-bottom} L${left},${h-bottom} Z" fill="currentColor" opacity=".09"/><path d="${real}" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linejoin="round"/><path d="${projection}" fill="none" stroke="var(--muted)" stroke-width="2.5" stroke-linejoin="round"/>${[0,2,4,6,8,10,12].map((n,i)=>`<text x="${x(n)}" y="${h-8}" text-anchor="${n===12?'end':'middle'}" class="axis-label">${['janv.','mars','mai','juil.','sept.','nov.','déc.'][i]}</text>`).join('')}</svg></div>`;
}
function monthlyChart(){
  if(state.private)return mask();
  const w=840,h=250,left=50,base=216,scale=180/4000;
  const colors={income:'var(--green)',expense:'var(--red)',investment:'var(--neutral)',remaining:'var(--text)'};
  const selected=[...state.series];
  const bars=shortMonths.map((label,i)=>{
    const center=left+29+i*64;
    return (i<10?selected.map((key,j)=>{
      const v=key==='remaining'?remainder(i):annual[key][i];
      const x=center-(selected.length*9+(selected.length-1)*3)/2+j*12;
      return `<rect x="${x}" y="${base-v*scale}" width="9" height="${v*scale}" rx="2" fill="${colors[key]}"><title>${label} · ${key==='remaining'?'Reste':types[key].label} : ${money(v)}</title></rect>`;
    }).join(''):'')+`<text x="${center}" y="241" text-anchor="middle" class="axis-label">${label}</text>`;
  }).join('');
  return `<div class="plot-scroll"><svg width="840" height="250" viewBox="0 0 ${w} ${h}" role="img" aria-label="Bilan mensuel fictif des revenus, dépenses, investissements et reste disponible"><title>Bilan des mois de janvier à octobre 2026</title>${[0,1000,2000,3000,4000].map(v=>`<line x1="${left}" y1="${base-v*scale}" x2="${w-8}" y2="${base-v*scale}" class="chart-grid"/><text x="${left-8}" y="${base-v*scale+4}" text-anchor="end" class="axis-label">${v?compact(v):'0 €'}</text>`).join('')}${bars}</svg></div>`;
}
function accountRows(){return accounts.map(a=>`<div class="account-row"><span class="account-icon">${icon(a.icon)}</span><div class="row-main"><strong>${a.name}</strong><small>${a.description}</small></div><span class="row-amount">${money(a.balance)}</span></div>`).join('');}
function ranking(rows,color){
  const ordered=[...rows].sort((a,b)=>b.amount-a.amount);
  const max=ordered[0]?.amount||1;
  return ordered.map((r,i)=>`<div class="ranking-row"><div class="ranking-label"><span>${i+1}. ${r.name}</span><strong>${money(r.amount)}</strong></div><div class="track"><span style="--width:${state.private?0:r.amount/max*100}%;background:${r.color||color}"></span></div></div>`).join('');
}
function renderGlobal(){
  const income=total(annual.income),expense=total(annual.expense),investment=total(annual.investment);
  return `<section class="balance-panel"><div class="balance-top"><div class="balance-title">${icon('global')}<div><h1>Vue globale</h1><small>3 comptes actifs</small></div></div><div class="period-inline"><strong>2026</strong></div></div><p class="muted">Solde global des comptes</p><div class="balance-amount">${money(total(accounts.map(a=>a.balance)))}</div><span class="chip green">${icon('stats')}Balance annuelle : ${money(income-expense)}</span></section><div class="metric-grid">${metric('Revenus annuels',income,'income')}${metric('Dépenses annuelles',expense,'expense')}${metric('Investissements annuels',investment,'investment')}${metric('Reste disponible',income-expense-investment,'remaining')}</div><section class="section"><div class="section-head"><h2>${icon('stats')}Évolution du patrimoine annuel</h2><div class="legend"><span><i class="legend-dot"></i>Réel</span><span><i class="legend-dot projection"></i>Projection</span></div></div>${wealthChart()}</section><details class="accounts-summary"><summary><div><h2>Comptes</h2><p class="subtitle">Solde global : ${money(22000)} · 3 comptes actifs</p></div>${icon('right')}</summary>${accountRows()}</details><section class="section"><div class="section-head"><h2>${icon('stats')}Bilan des revenus, dépenses et investissements</h2></div><div class="legend">${['income','expense','investment','remaining'].map(key=>`<button data-series="${key}" aria-pressed="${state.series.has(key)}"><i class="legend-dot" style="background:${key==='remaining'?'var(--text)':types[key].color}"></i>${key==='remaining'?'Reste disponible':types[key].label}</button>`).join('')}</div>${monthlyChart()}</section><div class="dashboard-lower"><section class="section"><div class="section-head"><h2>Principales dépenses du mois</h2></div>${ranking(expenseCategories,'var(--red)')}</section><section class="section"><div class="section-head"><h2>Répartition du patrimoine</h2></div>${ranking(accounts.map(a=>({name:a.name,amount:a.balance})),'var(--teal)')}</section></div>`;
}
function renderStats(){
  const available=remainder(9),projected=3200-1850/22*31-450;
  const comparison=[['Revenus',3200,3200],['Dépenses',1900,1850],['Investissements',450,450],['Reste disponible',850,900]];
  return `<div class="section-head"><div><h1>Statistiques</h1><p class="subtitle">Octobre 2026</p></div>${icon('stats')}</div><div class="metric-grid four">${metric('Patrimoine',22000,'remaining')}<article class="metric"><span class="metric-label">Taux d’épargne disponible</span><strong>${percent(available/3200*100)}</strong></article>${metric('Reste du mois',available,'income')}${metric('Projection fin de mois',projected,'investment')}</div><section class="section"><div class="section-head"><h2>Comparaison mensuelle</h2></div><div class="plot-scroll"><table class="comparison"><thead><tr><th>Indicateur</th><th>Septembre</th><th>Octobre</th><th>Écart</th></tr></thead><tbody>${comparison.map(([label,previous,current])=>`<tr><td>${label}</td><td>${money(previous)}</td><td><strong>${money(current)}</strong></td><td class="${current===previous?'muted':label==='Dépenses'?(current<previous?'green':'red'):(current>previous?'green':'red')}">${!state.private&&current>previous?'+':''}${money(current-previous)}</td></tr>`).join('')}</tbody></table></div></section><section class="projection-panel"><div class="section-head"><h2>Projection fin de mois</h2><span class="chip">Estimation</span></div><div class="projection-values"><div><small>Disponible au 22 octobre</small><strong>${money(available)}</strong></div><div><small>Disponible estimé au 31</small><strong>${money(projected)}</strong></div></div><div class="track"><span style="--width:71%;background:var(--neutral)"></span></div><p class="subtitle">Revenus encaissés, rythme de dépenses actuel et investissements déjà déduits.</p></section><div class="two-columns"><section class="section"><div class="section-head"><h2>Top dépenses</h2><span class="chip red">${money(1850)}</span></div>${ranking(expenseCategories,'var(--red)')}</section><section class="section"><div class="section-head"><h2>Top revenus</h2><span class="chip green">${money(3200)}</span></div>${ranking(incomeCategories,'var(--green)')}</section></div><section class="section"><div class="section-head"><h2>Revenus récurrents</h2></div><div class="account-row"><span class="account-icon">${icon('income')}</span><div class="row-main"><strong>Salaire mensuel</strong><small>Compte courant · reçu chaque mois</small></div><strong class="green row-amount">${money(3000)}</strong></div></section>`;
}
function profileRow(key,label,description,mark){return `<button class="profile-row" data-panel="${key}">${icon(mark)}<span class="row-main"><strong>${label}</strong><small>${description}</small></span>${icon('right')}</button>`;}
function renderProfile(){
  return `<div class="profile-wrap"><div class="profile-head"><div class="avatar" aria-hidden="true">AD</div><div><h1>Alex Démo</h1><p class="muted">Profil fictif</p></div></div><section class="profile-group"><h2>Gestion</h2>${profileRow('accounts','Comptes','Soldes et banques','bank')}${profileRow('categories','Catégories','Revenus et dépenses','category')}${profileRow('investments','Investissements','Actifs et supports','investment')}${profileRow('alerts','Limites','Alertes budget','alerts')}</section><section class="profile-group"><h2>Outils</h2>${profileRow('report','Export PDF','Rapport annuel, mensuel ou personnalisé','pdf')}</section><section class="profile-group"><h2>Préférences</h2>${profileRow('appearance','Apparence',state.light?'Thème clair':'Thème sombre','settings')}${profileRow('privacy','Sécurité et confidentialité','Démo statique · données fictives','lock')}</section></div>`;
}
function showDialog(title,html){
  document.getElementById('dialog-title').textContent=title;
  document.getElementById('dialog-body').innerHTML=html;
  if(!dialog.open)dialog.showModal();
}
function showTransaction(index){
  const r=transactionData()[index];
  if(!r)return;
  const field=(name,value)=>`<div class="detail-line"><span>${name}</span><strong>${value}</strong></div>`;
  const destination=state.type==='investment'?'Compte titres':state.type==='transfer'?'Livret d’épargne':null;
  showDialog(r.description,`<div class="detail-amount" style="color:${tint(state.type)}">${state.private?'':types[state.type].sign}${money(r.amount)}</div>${field('Type',types[state.type].label)}${field(state.type==='income'?'Compte crédité':'Compte débité','Compte courant')}${destination?field('Compte crédité',destination):''}${field(state.type==='investment'?'Actif':'Catégorie',r.name)}${field('Date',`${String(r.day).padStart(2,'0')} ${period()}`)}${detailsFootnote}`);
}
function showPanel(key){
  if(key==='accounts')showDialog('Gestion des comptes',accountRows()+detailsFootnote);
  if(key==='categories')showDialog('Gestion des catégories',`<h3>Dépenses</h3>${ranking(expenseCategories,'var(--red)')}<h3 class="section">Revenus</h3>${ranking(incomeCategories,'var(--green)')}${detailsFootnote}`);
  if(key==='investments')showDialog('Gestion des investissements',assets.map(a=>`<div class="account-row"><span class="account-icon">${icon('investment')}</span><div class="row-main"><strong>${a.name}</strong><small>${a.kind} · Compte titres</small></div><strong class="row-amount">${money(a.balance)}</strong></div>`).join('')+detailsFootnote);
  if(key==='alerts')showDialog('Alertes budgétaires',[50,75,90].map(n=>`<div class="account-row"><span class="account-icon">${icon('alerts')}</span><div class="row-main"><strong>${n} % des revenus du mois</strong><small>${n===50?'Seuil atteint':'Seuil non atteint'}</small></div><span class="chip">${n} %</span></div>`).join('')+detailsFootnote);
  if(key==='report')showDialog('Aperçu d’un rapport PDF',`<h3>MySold · Octobre 2026</h3><div class="metric-grid">${metric('Revenus',3200,'income')}${metric('Dépenses',1850,'expense')}${metric('Investissements',450,'investment')}${metric('Reste disponible',900,'remaining')}</div><section class="section"><h3>Principales dépenses</h3>${ranking(expenseCategories.slice(0,3),'var(--red)')}</section>${detailsFootnote}`);
  if(key==='appearance')showDialog('Apparence',`<button class="profile-row" data-demo-theme="dark">${icon('global')}<span class="row-main"><strong>Sombre</strong><small>Noir et nuances neutres</small></span></button><button class="profile-row" data-demo-theme="light">${icon('income')}<span class="row-main"><strong>Clair</strong><small>Fond clair et contrastes doux</small></span></button><p class="dialog-footnote">Préférence temporaire, réinitialisée au rechargement.</p>`);
  if(key==='privacy')showDialog('Sécurité et confidentialité','<p>Cette vitrine utilise uniquement des données fictives intégrées aux fichiers de démonstration.</p><p class="section">Aucun compte utilisateur, formulaire d’inscription, cookie, stockage local, suivi analytique ou appel à une API n’est utilisé. La recherche et les préférences visuelles restent temporaires dans la page.</p><p class="dialog-footnote">L’hébergeur du site peut conserver ses propres journaux techniques d’accès. Cette démonstration est indépendante de l’instance MySold et de sa base de données.</p>');
}
function setTheme(light){
  state.light=light;
  document.body.dataset.theme=light?'light':'dark';
  const button=document.getElementById('theme');
  const label=light?'Passer au thème sombre':'Passer au thème clair';
  button.title=label;button.setAttribute('aria-label',label);
  button.innerHTML=`<span class="mi" aria-hidden="true">&#${light?0xef9f:0xf162};</span>`;
  render();
}
function render(){
  document.querySelectorAll('[data-view]').forEach(a=>{
    if(a.dataset.view===state.view)a.setAttribute('aria-current','page');else a.removeAttribute('aria-current');
  });
  document.title=`MySold · ${state.view==='mois'?'Mois':state.view==='stats'?'Stats':state.view==='global'?'Global':'Profil'} · Démonstration`;
  content.innerHTML=state.view==='mois'?renderMonth():state.view==='global'?renderGlobal():state.view==='stats'?renderStats():renderProfile();
  if(state.view==='mois')renderTransactions();
}
function navigate(){
  const requested=location.hash.slice(1);
  state.view=views.includes(requested)?requested:'mois';state.search='';
  render();
  window.scrollTo(0,0);
}
document.getElementById('theme').addEventListener('click',()=>setTheme(!state.light));
document.getElementById('privacy').addEventListener('click',()=>{
  state.private=!state.private;
  const button=document.getElementById('privacy');
  const label=state.private?'Afficher les montants':'Masquer les montants';
  button.setAttribute('aria-pressed',String(state.private));button.setAttribute('aria-label',label);button.title=label;
  button.innerHTML=`<span class="mi" aria-hidden="true">&#${state.private?0xf4a0:0xf4a1};</span>`;
  state.search='';render();
});
document.getElementById('close-dialog').addEventListener('click',()=>dialog.close());
dialog.addEventListener('click',event=>{if(event.target===dialog){const r=dialog.getBoundingClientRect();if(event.clientX<r.left||event.clientX>r.right||event.clientY<r.top||event.clientY>r.bottom)dialog.close();}});
document.addEventListener('input',event=>{if(event.target.id==='search'){state.search=event.target.value;renderTransactions();}});
document.addEventListener('click',event=>{
  const button=event.target.closest('button');if(!button)return;
  if(button.dataset.month){state.month=Math.max(0,Math.min(9,state.month+Number(button.dataset.month)));state.search='';render();}
  if(button.dataset.type&&Object.hasOwn(types,button.dataset.type)){state.type=button.dataset.type;state.search='';render();}
  if(button.dataset.transaction!==undefined)showTransaction(Number(button.dataset.transaction));
  if(button.dataset.panel)showPanel(button.dataset.panel);
  if(button.dataset.demoTheme){dialog.close();setTheme(button.dataset.demoTheme==='light');}
  if(button.dataset.series){const key=button.dataset.series;if(state.series.has(key)){if(state.series.size===1)return;state.series.delete(key);}else state.series.add(key);render();}
});
window.addEventListener('hashchange',navigate);
navigate();
