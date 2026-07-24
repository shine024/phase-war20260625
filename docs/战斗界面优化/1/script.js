// 卡牌点击高亮
document.querySelectorAll(".card").forEach(card=>{
  card.onclick=function(){
    document.querySelectorAll(".card").forEach(c=>c.classList.remove("active"));
    this.classList.add("active");
  };
});

// 单位点击选中
document.querySelectorAll(".unit").forEach(u=>{
  u.onclick=function(){
    document.querySelectorAll(".unit").forEach(x=>x.classList.remove("selected"));
    this.classList.add("selected");
  };
});

// 模拟伤害飘字循环
setInterval(()=>{
  const d=document.querySelector(".damage");
  if(!d) return;
  d.style.animation="none";
  // 触发重绘以重启动画
  void d.offsetWidth;
  d.style.animation="float 1.2s ease-out forwards";
  d.textContent=Math.floor(150+Math.random()*300);
},2000);

// 模拟技能冷却动画
document.querySelectorAll(".skills button").forEach(btn=>{
  btn.onclick=function(){
    const cd=this.querySelector(".cd");
    if(!cd) return;
    cd.style.height="100%";
    let h=100;
    const timer=setInterval(()=>{
      h-=2;
      cd.style.height=h+"%";
      if(h<=0) clearInterval(timer);
    },50);
  };
});
