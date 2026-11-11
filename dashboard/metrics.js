(function(root){
 'use strict';
 const empty=()=>({orders:0,value:0,freight:0,delivered:0,late:0,leadSum:0,leadN:0,reviewSum:0,reviewN:0,risk:0,canceled:0,items:0});
 function aggregate(data,filters={}){
  const total=empty(),months={},states={},categories={},sellers={},statuses={};
  for(const row of data.rows){
   const [month,state,status,lead,late,review,allItems]=row;
   if(filters.start!==undefined&&month<filters.start||filters.end!==undefined&&month>filters.end||filters.state!==undefined&&state!==filters.state||filters.status!==undefined&&status!==filters.status)continue;
   const items=filters.category===undefined?allItems:allItems.filter(x=>x[0]===filters.category);if(!items.length)continue;
   const canceled=data.statuses[status]==='canceled',risk=canceled||late===1;
   const value=items.reduce((a,x)=>a+x[2],0),freight=items.reduce((a,x)=>a+x[3],0);
   function add(t,v=value,f=freight,n=items.length){t.orders++;t.value+=v;t.freight+=f;t.items+=n;if(canceled)t.canceled++;if(risk)t.risk+=v;if(late!==null){t.delivered++;t.late+=late;}if(lead!==null){t.leadSum+=lead;t.leadN++;}if(review!==null){t.reviewSum+=review;t.reviewN++;}}
   add(total);add(months[month]??=empty());add(states[state]??=empty());statuses[status]=(statuses[status]||0)+1;
   const cats=new Map(),sells=new Map();
   for(const item of items){for(const [map,key] of [[cats,item[0]],[sells,item[1]]]){const a=map.get(key)||[0,0,0];a[0]+=item[2];a[1]+=item[3];a[2]++;map.set(key,a);}}
   for(const [key,[v,f,n]] of cats)add(categories[key]??=empty(),v,f,n);
   for(const [key,[v,f,n]] of sells)add(sellers[key]??=empty(),v,f,n);
  }
  return {total,months,states,categories,sellers,statuses};
 }
 const api={aggregate,empty};if(typeof module!=='undefined')module.exports=api;else root.OlistMetrics=api;
})(globalThis);
