'use strict';
const $=s=>document.querySelector(s),esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const br=new Intl.NumberFormat('pt-BR'),currency=new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',maximumFractionDigits:0}),compact=new Intl.NumberFormat('pt-BR',{notation:'compact',maximumFractionDigits:2});
const money=v=>currency.format(v/100),number=v=>br.format(v),pct=(a,b)=>b?(a/b*100).toLocaleString('pt-BR',{maximumFractionDigits:1})+'%':'—',avg=(a,n)=>n?(a/n).toLocaleString('pt-BR',{maximumFractionDigits:1}):'—';
const categoryName=s=>s==='sem_categoria'?'Sem categoria':s.replaceAll('_',' ').replace(/^./,c=>c.toUpperCase());
const statusNames={delivered:'Entregue',canceled:'Cancelado',shipped:'Enviado',unavailable:'Indisponível',invoiced:'Faturado',processing:'Em processamento',created:'Criado',approved:'Aprovado'};
const viewMeta={overview:['Visão geral do negócio','Vendas, experiência e operação em uma visão conectada.'],logistics:['Da compra à entrega','Entenda o prazo e a pontualidade em cada estado.'],financial:['Categorias que movem o negócio','Volume de produtos, frete e exposição a ocorrências.'],suppliers:['Qualidade da rede de fornecedores','Volume, experiência e pontualidade no mesmo recorte.']};
let data,current,view='overview',exportRows=[],exportHeaders=[];
function filters(){const f={};for(const key of ['start','end','state','category','status'])if($('#'+key).value!=='')f[key]=Number($('#'+key).value);return f;}
function kpi(label,value,sub,style='',icon='◫'){return `<article class="kpi ${style}"><p class="kpi-label">${label}<span>${icon}</span></p><div class="kpi-value">${value}</div><p class="kpi-sub">${sub}</p></article>`;}
function panel(title,sub,content,pill=''){return `<section class="panel"><div class="panel-head"><div><h2>${title}</h2><p>${sub}</p></div>${pill?`<span class="panel-pill">${pill}</span>`:''}</div>${content}</section>`;}
function bars(entries,key='value',formatter=money,color='',limit=6){const rows=entries.slice(0,limit),max=Math.max(...rows.map(x=>x[1][key]),1);return `<div class="bars ${color}">${rows.map(([label,m])=>`<div><div class="bar-top"><span title="${esc(label)}">${esc(label)}</span><strong>${formatter(m[key])}</strong></div><div class="bar-track"><div class="bar-fill" style="width:${Math.max(0,m[key]/max*100)}%"></div></div></div>`).join('')}</div>`;}
function lineChart(entries,key,label,formatter){
 if(!entries.length)return '<p class="empty">Nenhum dado neste período.</p>';
 const W=680,H=230,L=65,R=20,T=18,B=32,max=Math.max(...entries.map(x=>x[1][key]),1)*1.15;
 const x=i=>L+(W-L-R)*i/Math.max(entries.length-1,1),y=v=>H-B-(H-B-T)*v/max;
 const points=entries.map((e,i)=>`${x(i)},${y(e[1][key])}`).join(' ');
 let svg=`<svg class="line-chart" viewBox="0 0 ${W} ${H}" role="img" aria-label="${esc(label)}"><title>${esc(label)}</title>`;
 for(let j=0;j<4;j++){const v=max*j/3;svg+=`<line x1="${L}" x2="${W-R}" y1="${y(v)}" y2="${y(v)}" stroke="#e8eef1"/><text x="${L-10}" y="${y(v)+4}" text-anchor="end">${esc(formatter(v))}</text>`;}
 svg+=`<polygon points="${L},${H-B} ${points} ${x(entries.length-1)},${H-B}" fill="#edf3ff"/><polyline points="${points}" fill="none" stroke="#366ee8" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/>`;
 entries.forEach(([m,v],i)=>{if(i===0||i===entries.length-1||i%Math.ceil(entries.length/5)===0)svg+=`<text x="${x(i)}" y="${H-6}" text-anchor="middle">${esc(data.months[m].slice(5)+'/'+data.months[m].slice(2,4))}</text>`;svg+=`<circle cx="${x(i)}" cy="${y(v[key])}" r="5" fill="#366ee8" stroke="white" stroke-width="2" tabindex="0"><title>${data.months[m]}: ${esc(formatter(v[key]))}</title></circle>`;});
 return svg+'</svg>';
}
function table(title,sub,headers,rows,caption){exportHeaders=headers;exportRows=rows.map(r=>r.map(c=>typeof c==='object'?c.text:c));return `<section class="panel table-panel"><div class="panel-head"><div><h2>${title}</h2><p>${sub}</p></div><span class="panel-pill">${rows.length} linhas</span></div><div class="table-scroll"><table><thead><tr>${headers.map(h=>`<th scope="col">${esc(h)}</th>`).join('')}</tr></thead><tbody>${rows.map(r=>`<tr>${r.map((c,i)=>`<td${i===0?' class="row-label"':''}>${typeof c==='object'?`<span class="segment ${c.style}">${esc(c.text)}</span>`:esc(c)}</td>`).join('')}</tr>`).join('')}</tbody></table></div><p class="table-caption">${caption}</p></section>`;}
function insight(title,text){return `<aside class="insight"><span class="insight-symbol" aria-hidden="true">✳</span><div><h3>${title}</h3><p>${text}</p></div></aside>`;}
function render(){
 if(!data)return;const f=filters();$('#error').hidden=true;
 if(f.start>f.end){$('#error').hidden=false;$('#error').textContent='O mês inicial precisa ser anterior ou igual ao mês final.';$('#dashboard-content').innerHTML='';$('#kpis').innerHTML='';$('#export').disabled=true;return;}
 current=OlistMetrics.aggregate(data,f);const t=current.total;window.olistCurrent=current;
 const [title,subtitle]=viewMeta[view];$('#view-title').textContent=title;$('#view-subtitle').textContent=subtitle;
 $('#context').textContent=`${number(t.orders)} pedidos com itens · ${data.months[f.start]} a ${data.months[f.end]} · ${number(data.excludedNoItems)} pedidos sem itens excluídos da base`;
 document.querySelectorAll('[data-view]').forEach(b=>{b.classList.toggle('active',b.dataset.view===view);if(b.dataset.view===view)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current');});
 $('#export').disabled=!t.orders;
 if(!t.orders){$('#kpis').innerHTML='';$('#dashboard-content').innerHTML='<div class="empty"><strong>Nenhum pedido neste recorte.</strong><br>Experimente ampliar o período ou limpar os filtros.</div>';exportRows=[];return;}
 const monthly=Array.from({length:f.end-f.start+1},(_,i)=>{const month=f.start+i;return [month,current.months[month]||OlistMetrics.empty()];});
 const cats=Object.entries(current.categories).sort((a,b)=>b[1].value-a[1].value).map(([k,m])=>[categoryName(data.categories[k]),m]);
 const states=Object.entries(current.states).sort((a,b)=>b[1].value-a[1].value).map(([k,m])=>[data.states[k],m]);
 const sla=pct(t.delivered-t.late,t.delivered),review=avg(t.reviewSum,t.reviewN);
 $('#kpis').innerHTML=view==='logistics'?
  kpi('Entregas no prazo',sla,`${number(t.delivered)} entregas com datas válidas`,'teal','✓')+kpi('Tempo médio até entrega',avg(t.leadSum,t.leadN)+' dias','Uma observação por pedido entregue')+kpi('Entregas em atraso',number(t.late),'Após o dia prometido','amber','!')+kpi('Pedidos cancelados',number(t.canceled),`${pct(t.canceled,t.orders)} dos pedidos selecionados`):
  view==='suppliers'?kpi('Fornecedores no recorte',number(Object.keys(current.sellers).length),'Com pelo menos um item selecionado')+kpi('Avaliação por pedido',review+' / 5',`${number(t.reviewN)} pedidos avaliados`,'teal','☆')+kpi('Entregas no prazo',sla,'Somente entregas com datas válidas')+kpi('Pedidos com itens',number(t.orders),'Pedidos distintos no recorte'):
  kpi('Valor em produtos',money(t.value),'Preços dos itens · sem frete')+kpi('Pedidos com itens',number(t.orders),`${number(t.items)} itens no recorte`)+kpi(view==='financial'?'Frete / valor dos produtos':'Entregas no prazo',view==='financial'?pct(t.freight,t.value):sla,view==='financial'?'Razão de valores, não margem':'Somente entregas com datas válidas','teal','✓')+kpi(view==='financial'?'Valor com ocorrência':'Avaliação média',view==='financial'?money(t.risk):review+' / 5',view==='financial'?'Atraso ou cancelamento · não é perda':`${number(t.reviewN)} pedidos avaliados`,view==='financial'?'amber':'','☆');
 let html='';
 if(view==='overview'){
  html=`<div class="chart-grid">${panel('Evolução do valor em produtos','Por mês da compra · extremos da base podem estar incompletos',lineChart(monthly,'value','Valor em produtos por mês',v=>'R$ '+compact.format(v/100)),'HISTÓRICO')}${panel('Categorias em destaque','As seis maiores por valor de produtos',bars(cats),'TOP 6')}</div>`;
  html+=insight('O que este recorte mostra',`${esc(cats[0][0])} lidera em valor de produtos, com ${money(cats[0][1].value)} (${pct(cats[0][1].value,t.value)} do total). O ticket de produtos é ${money(t.value/t.orders)} por pedido selecionado.`);
  html+=table('Leitura regional','Valor e qualidade da entrega por estado do cliente',['Estado','Pedidos','Valor em produtos','No prazo','Entrega média'],states.map(([s,m])=>[s,number(m.orders),money(m.value),pct(m.delivered-m.late,m.delivered),avg(m.leadSum,m.leadN)+' dias']),'Os percentuais consideram somente pedidos entregues com datas válidas. Estado se refere ao cliente.');
 }else if(view==='logistics'){
  const ranking=states.map(([s,m])=>[s,{...m,lead:m.leadN?m.leadSum/m.leadN:0}]).filter(x=>x[1].leadN).sort((a,b)=>b[1].lead-a[1].lead);
  const trend=monthly.map(([k,m])=>[k,{lead:m.leadN?m.leadSum/m.leadN:0}]).filter(([k])=>current.months[k]?.leadN);
  html=`<div class="chart-grid">${panel('Tempo de entrega ao longo do tempo','Média de dias corridos · por mês da compra',lineChart(trend,'lead','Tempo médio de entrega por mês',v=>v.toLocaleString('pt-BR',{maximumFractionDigits:1})+' d'))}${panel('Onde a entrega leva mais tempo','Até seis estados com entrega observada',bars(ranking,'lead',v=>v.toLocaleString('pt-BR',{maximumFractionDigits:1})+' dias','amber'),'TOP 6')}</div>`;
  html+=insight('Uma taxa com denominador explícito',`${number(t.delivered-t.late)} de ${number(t.delivered)} entregas válidas chegaram até o dia prometido. Pedidos em trânsito, cancelados ou sem datas não aumentam artificialmente a pontualidade.`);
  html+=table('Qualidade da entrega por estado','Comparação sem depender de geocodificação',['Estado','Entregas válidas','Atrasos','No prazo','Entrega média','Frete dos itens'],states.map(([s,m])=>[s,number(m.delivered),number(m.late),pct(m.delivered-m.late,m.delivered),avg(m.leadSum,m.leadN)+' dias',money(m.freight)]),'Entrega média usa dias corridos com precisão fracionária; não é uma promessa de prazo futuro.');
 }else if(view==='financial'){
  const riskCats=[...cats].sort((a,b)=>b[1].risk-a[1].risk);
  html=`<div class="view-two">${panel('Participação no valor de produtos','Seis maiores categorias',bars(cats))}${panel('Valor ligado a ocorrências','Itens em pedidos atrasados ou cancelados',bars(riskCats,'risk',money,'amber'))}</div>`;
  html+=insight('Ocorrência operacional não é prejuízo',`${money(t.risk)} (${pct(t.risk,t.value)} do valor selecionado) estão ligados a pedidos cancelados ou com atraso. A base não informa devoluções, margem ou recuperação; esse valor não deve ser interpretado como perda.`);
  html+=table('Categorias em detalhe','Preço dos itens atribuído à categoria correta',['Categoria','Pedidos','Valor em produtos','Frete','Valor com ocorrência','% com ocorrência'],cats.map(([s,m])=>[s,number(m.orders),money(m.value),money(m.freight),money(m.risk),pct(m.risk,m.value)]),'Um pedido com várias categorias aparece em mais de uma linha; os valores de itens e frete são aditivos, mas as contagens de pedidos não são.');
 }else{
  const sellers=Object.entries(current.sellers).sort((a,b)=>b[1].value-a[1].value);
  const segments={'Destaque':0,'Regular':0,'Atenção':0,'Sem base':0};
  const segment=m=>!m.reviewN||!m.delivered?'Sem base':m.reviewSum/m.reviewN>=4.5&&(m.delivered-m.late)/m.delivered>=.9&&m.orders>=10?'Destaque':m.reviewSum/m.reviewN>=3.5&&(m.delivered-m.late)/m.delivered>=.7?'Regular':'Atenção';
  sellers.forEach(([,m])=>segments[segment(m)]++);
  html=`<div class="view-two">${panel('Perfil da rede neste recorte','Segmentação calculada com pedidos distintos',bars(Object.entries(segments).map(([k,v])=>[k,{value:v}]),'value',number,'teal'))}${panel('Participação dos maiores fornecedores','Seis maiores por valor dos itens',bars(sellers.map(([id,m])=>['Fornecedor '+String(+id+1).padStart(4,'0'),m])),'TOP 6')}</div>`;
  html+=insight('Notas sem multiplicação por itens','Cada fornecedor recebe uma observação por pedido. Se o mesmo pedido tiver vários fornecedores, a avaliação do pedido é atribuída a cada um; essa é uma aproximação explícita, não uma nota individual do vendedor.');
  html+=table('Fornecedores em destaque','Até 30 fornecedores por valor de produtos; códigos locais sem identificadores originais',['Fornecedor','Pedidos','Valor em produtos','Nota média','No prazo','Segmento'],sellers.slice(0,30).map(([id,m])=>{const s=segment(m);return ['Fornecedor '+String(+id+1).padStart(4,'0'),number(m.orders),money(m.value),avg(m.reviewSum,m.reviewN),pct(m.delivered-m.late,m.delivered),{text:s,style:s==='Destaque'?'good':s==='Atenção'?'warn':''}];}),'A segmentação muda com os filtros. Fornecedores com amostras pequenas exigem cautela; não há inferência estatística de desempenho futuro.');
 }
 $('#dashboard-content').innerHTML=html;$('#dashboard-content').setAttribute('aria-busy','false');
}
function option(select,value,label){const o=document.createElement('option');o.value=value;o.textContent=label;select.append(o);}
async function init(){try{const response=await fetch('data.json');if(!response.ok)throw new Error('Dados indisponíveis');data=await response.json();data.months.forEach((m,i)=>{option($('#start'),i,m);option($('#end'),i,m);});data.states.forEach((s,i)=>option($('#state'),i,s));data.categories.forEach((c,i)=>option($('#category'),i,categoryName(c)));data.statuses.forEach((s,i)=>option($('#status'),i,statusNames[s]||s));$('#start').value=0;$('#end').value=data.months.length-1;document.querySelectorAll('#filters select,#filters button').forEach(e=>e.disabled=false);render();}catch(error){$('#context').textContent='Dados indisponíveis';$('#error').hidden=false;$('#error').textContent='Não foi possível carregar a base. Atualize a página para tentar novamente.';$('#dashboard-content').innerHTML='';$('#dashboard-content').setAttribute('aria-busy','false');}}
$('#filters').addEventListener('submit',e=>e.preventDefault());$('#filters').addEventListener('change',render);
$('#reset').addEventListener('click',()=>{$('#start').value=0;$('#end').value=data.months.length-1;for(const key of ['state','category','status'])$('#'+key).value='';render();});
document.querySelectorAll('[data-view]').forEach(b=>b.addEventListener('click',()=>{view=b.dataset.view;render();}));
$('#export').addEventListener('click',()=>{const f=filters(),context=[['Visao',viewMeta[view][0]],['Periodo',data.months[f.start]+' a '+data.months[f.end]],['Estado',f.state===undefined?'Todos':data.states[f.state]],['Categoria',f.category===undefined?'Todas':data.categories[f.category]],['Status',f.status===undefined?'Todos':data.statuses[f.status]],[]];const csv='\ufeff'+[...context,exportHeaders,...exportRows].map(r=>r.map(v=>'"'+String(v).replace(/^[=+@-]/,"'$&").replaceAll('"','""')+'"').join(';')).join('\r\n');const url=URL.createObjectURL(new Blob([csv],{type:'text/csv;charset=utf-8'}));const a=document.createElement('a');a.href=url;a.download='olist-'+view+'-resumo.csv';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);});
$('#method-button').addEventListener('click',()=>$('#method').showModal());$('#close-method').addEventListener('click',()=>$('#method').close());init();
