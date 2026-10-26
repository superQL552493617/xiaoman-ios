#!/usr/bin/env python3
"""把 en.json / zh-Hant.json 词典写进 xiaoman.html（I18N_DICT），并列出界面里还没翻译的中文。
用法：python3 DailyReview/i18n/build_i18n.py [--missing]"""
import json,re,sys,os
H=os.path.dirname(os.path.abspath(__file__))
P=os.path.join(H,'..','App','Web','xiaoman.html')
s=open(P,encoding='utf8').read()
D={l:json.load(open(os.path.join(H,l+'.json'),encoding='utf8')) for l in ('en','zh-Hant')}
blob='const I18N_DICT='+json.dumps(D,ensure_ascii=False,separators=(',',':')).replace('</','<\\/')+';'
a=s.index('/*I18N_DICT_BEGIN*/')+len('/*I18N_DICT_BEGIN*/'); b=s.index('/*I18N_DICT_END*/')
s=s[:a]+blob+s[b:]
open(P,'w',encoding='utf8').write(s)
print('dict:',{k:len(v) for k,v in D.items()})
if '--missing' in sys.argv:
    t=re.sub(r'/\*I18N_DICT_BEGIN\*/.*?/\*I18N_DICT_END\*/','',s,flags=re.S)
    t=re.sub(r'<style.*?</style>','',t,flags=re.S); t=re.sub(r'<!--.*?-->','',t,flags=re.S)
    t=re.sub(r'(^|[\s;{}),])/\*.*?\*/',r'\1',t,flags=re.S); t=re.sub(r'(^|[\s;{}),])//[^\n]*',r'\1',t)
    HAN=re.compile(r'[㐀-鿿]'); out=set()
    def proc(x):
        res=[];i=0
        while i<len(x):
            if x[i]=='$' and i+1<len(x) and x[i+1]=='{':
                d=1;j=i+2
                while j<len(x) and d:
                    d+= {'{':1,'}':-1}.get(x[j],0); j+=1
                proc(x[i+2:j-1]); res.append('{}'); i=j; continue
            res.append(x[i]); i+=1
        for c in re.split(r'[<>\'"`\n]',''.join(res)):
            c=c.strip().replace('&nbsp;',' ')
            if HAN.search(c) and c not in D['en']: out.add(c)
    proc(t)
    for c in sorted(out): print('MISSING',c)
