// Original 40px baseball art. Rebuild: node tools/make-sprites.mjs
// Draw onto a fixed pixel grid; every frame uses the same baseline and origin.
import { writeFileSync } from 'node:fs'
const N = 40
let grid
function clear() { grid = Array.from({length:N}, () => Array(N).fill('.')) }
function dot(x,y,c) { x=Math.round(x);y=Math.round(y);if(x>=0&&x<N&&y>=0&&y<N)grid[y][x]=c }
function disk(x,y,r,c) { for(let yy=Math.floor(y-r);yy<=y+r;yy++)for(let xx=Math.floor(x-r);xx<=x+r;xx++)if((xx-x)**2+(yy-y)**2<=r*r)dot(xx,yy,c) }
function line(a,b,w,c) { const n=Math.max(1,Math.ceil(Math.hypot(b[0]-a[0],b[1]-a[1])*2));for(let i=0;i<=n;i++)disk(a[0]+(b[0]-a[0])*i/n,a[1]+(b[1]-a[1])*i/n,w/2,c) }
function limb(points,w=4) { for(let i=1;i<points.length;i++)line(points[i-1],points[i],w,'#');for(let i=1;i<points.length;i++)line(points[i-1],points[i],Math.max(1,w-2),'o') }
function poly(points,c) { for(let y=0;y<N;y++)for(let x=0;x<N;x++){let inside=false;for(let i=0,j=points.length-1;i<points.length;j=i++){const a=points[i],b=points[j];if((a[1]>y)!=(b[1]>y)&&x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0])inside=!inside}if(inside)dot(x,y,c)} }
function outlined(points) {poly(points,'o');for(let i=0;i<points.length;i++)line(points[i],points[(i+1)%points.length],2,'#')}
function shoe(p,dir=1) { line([p[0]-1,p[1]],[p[0]+dir*3,p[1]],2.5,'#') }
function head(x,y,dir=1,helmet=false) {
    disk(x,y+3,4.2,'#');disk(x+dir,y+3,3,'o');
    poly([[x-3,y-3],[x+2,y-3],[x+4,y-1],[x+5,y+2],[x-5,y+2],[x-4,y-1]],'#');
    line([x,y+1],[x+dir*7,y+1],1.7,'#');
    dot(x+dir*3,y+3,'#');dot(x-dir*2,y+5,'#');
    if(helmet)line([x-dir*3,y+2],[x-dir*3,y+5],2,'#')
}
function body(cx,cy,lean=0) {
    outlined([[cx-4+lean,cy],[cx+4+lean,cy],[cx+5,cy+10],[cx-4,cy+10]]);
    line([cx-4,cy+9],[cx+4,cy+9],2,'#');
    poly([[cx-3+lean,cy+2],[cx-1+lean,cy+3],[cx-1,cy+8],[cx-3,cy+8]],'+');
    line([cx-2+lean,cy],[cx+lean,cy+2],1,'#');line([cx+lean,cy+2],[cx+2+lean,cy],1,'#');
    line([cx+1,cy+4],[cx+3,cy+4],1,'#');line([cx+3,cy+4],[cx+1,cy+7],1,'#');
}
function batter(pose) {
    clear();
    const follow=pose==='follow',swing=pose==='swing',bunt=pose==='bunt',load=pose==='load';
    const hip=[19,25];
    limb([hip,[14,30],[11,36]],5);limb([[21,25],[25,30],[29,36]],5);
    shoe([11,37],-1);shoe([29,37],1);
    body(19,15,follow?2:0);head(20,8,1,true);
    let hands=bunt?[30,21]:swing?[29,19]:follow?[10,14]:load?[14,13]:[15,17];
    let tip=bunt?[36,12]:swing?[38,15]:follow?[3,7]:load?[4,3]:[5,4];
    line(hands,tip,3,'#');line(hands,tip,1,'o');
    limb([[16,17],bunt?[21,22]:swing?[22,20]:[12,21],hands],4);
    limb([[23,17],bunt?[26,21]:follow?[20,15]:[23,23],hands],4);
    disk(hands[0],hands[1],1.5,'#');
    return grid.map(r=>r.join(''));
}
function pitcher(pose) {
    clear();
    const wind=pose==='windup',release=pose==='release',follow=pose==='follow';
    if(wind){limb([[18,25],[19,31],[19,36]],5);limb([[21,25],[28,24],[27,30]],5);shoe([19,37]);shoe([27,31])}
    else if(release||follow){limb([[18,25],[12,30],[7,36]],5);limb([[22,25],[28,30],[33,36]],5);shoe([7,37],-1);shoe([33,37])}
    else {limb([[17,25],[16,31],[15,36]],5);limb([[23,25],[24,31],[25,36]],5);shoe([15,37],-1);shoe([25,37])}
    body(20,15,follow?-2:0);head(20,8,follow?-1:1);
    if(wind){limb([[16,17],[12,12],[17,7]],4);limb([[24,17],[27,12],[22,7]],4);disk(18,7,3,'#');disk(18,7,1.5,'+')}
    else if(release){limb([[24,17],[29,10],[27,4]],4);limb([[16,17],[11,22],[7,20]],4);disk(7,20,3,'#');disk(7,20,1.5,'+')}
    else if(follow){limb([[23,17],[20,22],[14,27]],4);limb([[16,17],[10,19],[9,15]],4);disk(9,15,3,'#');disk(9,15,1.5,'+')}
    else{limb([[16,17],[12,22],[19,20]],4);limb([[24,17],[27,22],[21,20]],4);disk(20,20,3,'#');disk(20,20,1.5,'+')}
    return grid.map(r=>r.join(''));
}
function runner(stride) {
    clear();
    if(stride){limb([[19,25],[12,28],[8,35]],4);limb([[21,25],[27,29],[29,25]],4);shoe([8,36],-1);shoe([29,25]);}
    else{limb([[19,25],[15,31],[10,31]],4);limb([[21,25],[25,30],[30,36]],4);shoe([10,32],-1);shoe([30,37]);}
    body(20,15,2);head(23,8,1,true);
    limb([[18,17],[12,21],[9,17]],4);limb([[25,17],[29,21],[33,16]],4);
    return grid.map(r=>r.join(''));
}
clear();
limb([[16,27],[10,30],[9,36]],6);limb([[24,27],[30,30],[31,36]],6);shoe([9,37],-1);shoe([31,37]);
outlined([[14,19],[26,19],[28,30],[12,30]]);head(20,12,-1,true);
for(let y=22;y<29;y+=3)line([15,y],[25,y],1,'#');
limb([[13,21],[8,25],[6,21]],4);limb([[27,21],[31,26],[30,29]],4);disk(6,21,3,'#');disk(6,21,1.6,'+');
const catcher=grid.map(r=>r.join(''));
const art={BATTER_STANCE:batter('stance'),BATTER_LOAD:batter('load'),BATTER_SWING:batter('swing'),BATTER_FOLLOW:batter('follow'),BATTER_BUNT:batter('bunt'),PITCHER_SET:pitcher('set'),PITCHER_WINDUP:pitcher('windup'),PITCHER_THROW:pitcher('release'),PITCHER_FOLLOW:pitcher('follow'),RUNNER:runner(0),RUNNER_ALT:runner(1),CATCHER:catcher};
writeFileSync(new URL('./legacy-sprites.mjs',import.meta.url),'// Original 40×40 monochrome sprites. Generated by tools/make-sprites.mjs.\n// # ink, + grey, o white, . transparent. Shared baseline keeps poses stable.\n'+Object.entries(art).map(([name,rows])=>'export const '+name+' = '+JSON.stringify(rows,null,4)+';').join('\n\n')+'\n');
