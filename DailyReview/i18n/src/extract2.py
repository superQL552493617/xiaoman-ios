import re,json
P='/home/claude/xiaoman-ios-prep/DailyReview/App/Web/xiaoman.html'
s=open(P).read()
s=re.sub(r'<style.*?</style>','',s,flags=re.S)
s=re.sub(r'<!--.*?-->','',s,flags=re.S)
s=re.sub(r'/\*.*?\*/','',s,flags=re.S)
s=re.sub(r'(^|[\s;{}),])//[^\n]*',r'\1',s)
HAN=re.compile(r'[㐀-鿿]')
out={}
def emit(t):
    t=t.strip()
    t=re.sub(r'^[\s,.:;!?·•|/\-–—+*~]+','',t) if False else t
    if HAN.search(t): out[t]=out.get(t,0)+1
def process(t):
    # replace balanced ${...} with \x01, recursing into inner
    res=[];i=0;n=len(t)
    while i<n:
        if t[i]=='$' and i+1<n and t[i+1]=='{':
            d=1;j=i+2
            while j<n and d:
                if t[j]=='{': d+=1
                elif t[j]=='}': d-=1
                j+=1
            process(t[i+2:j-1]); res.append('\x01'); i=j; continue
        res.append(t[i]); i+=1
    t=''.join(res)
    for c in re.split(r'[<>\'"`\n]',t): emit(c)
process(s)
# normalise placeholders
d={}
for k,v in out.items():
    k2=re.sub(r'\x01','{}',k)
    d[k2]=d.get(k2,0)+v
json.dump(d,open('keys.json','w'),ensure_ascii=False,indent=0)
print(len(d),sum(len(k) for k in d),sum(1 for k in d if '{}' in k))
