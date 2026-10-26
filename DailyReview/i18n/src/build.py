import json,re,glob,sys
sys.path.insert(0,'.')
from s2tw import conv
keys=json.load(open('klist.json'))
en={}
for f in sorted(glob.glob('en_*.tsv')):
    for line in open(f):
        line=line.rstrip('\n')
        if not line: continue
        i,_,v=line.partition('\t'); en[int(i)]=v
OVR={311:'Mon',312:'Tue',313:'Wed',314:'Thu',315:'Fri',316:'Sat',317:'Sun',327:'Mon',328:'Sun',799:'Tue',800:'Wed',801:'Thu',802:'Fri',803:'Sat'}
en.update(OVR)
# extra keys (added by hand, not in source scan)
EXTRA=json.load(open('extra.json')) if glob.glob('extra.json') else {}
TWFIX=[('周','週'),('小元件','小工具'),('賬戶','帳號'),('賬號','帳號'),('面容 ID','Face ID'),('面容ID','Face ID'),('雲盤','雲碟'),('鏈接','連結'),('信息','訊息')]
def hant(s):
    t=conv(s)
    for a,b in TWFIX: t=t.replace(a,b)
    return t
def num(v):
    n=[0]
    def r(m):
        x='{%d}'%n[0]; n[0]+=1; return x
    return re.sub(r'\{\}',r,v)
E_, H_ = {}, {}
for i,k in enumerate(keys):
    v=en.get(i)
    if v is None or v=='SKIP': continue
    kk=k.replace('&nbsp;',' ')
    E_[kk]=v
    h=num(hant(kk))
    if h!=num(kk) or '{}' in kk: H_[kk]=h
for k,(ve,vh) in EXTRA.items():
    E_[k]=ve; H_[k]=vh or num(hant(k))
# 繁体兜底：逐字转换表（词典里没有的文字用它转）
from s2tw import ST,TWV
cm={}
for k,v in ST.items():
    if len(k)==1 and len(v)==1 and k!=v and ord(k)<0x10000 and ord(v)<0x10000: cm[k]=TWV.get(v,v)
cm['周']='週';cm['干']='乾'
H_['__chars__']=''.join(k+v for k,v in sorted(cm.items()))
json.dump({'en':E_,'zh-Hant':H_},open('dict.json','w'),ensure_ascii=False,separators=(',',':'))
print(len(E_),len(H_),len(json.dumps({'en':E_,'zh-Hant':H_},ensure_ascii=False))//1024,'KB')
