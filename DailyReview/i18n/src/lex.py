import re,sys,json
CJK=re.compile(r'[㐀-鿿！-～　-〿]')
HAN=re.compile(r'[㐀-鿿]')
def lex(src):
    """yield (kind, text, start) for JS string/template literals; kind in 's','t'. template text has ${..} replaced by \x00k\x00"""
    i=0;n=len(src);out=[];prev=''  # prev significant char
    while i<n:
        c=src[i]
        if c=='/' and i+1<n and src[i+1]=='/':
            j=src.find('\n',i); i=n if j<0 else j; continue
        if c=='/' and i+1<n and src[i+1]=='*':
            j=src.find('*/',i+2); i=n if j<0 else j+2; continue
        if c in '\'"':
            j=i+1;buf=[]
            while j<n and src[j]!=c:
                if src[j]=='\\': buf.append(src[j:j+2]); j+=2; continue
                if src[j]=='\n': break
                buf.append(src[j]); j+=1
            out.append(('s',''.join(buf),i,j+1)); i=j+1; prev='a'; continue
        if c=='`':
            j=i+1;buf=[];k=0
            while j<n and src[j]!='`':
                if src[j]=='\\': buf.append(src[j:j+2]); j+=2; continue
                if src[j]=='$' and j+1<n and src[j+1]=='{':
                    # skip balanced braces, recursively lex inner
                    d=1;m=j+2
                    while m<n and d:
                        ch=src[m]
                        if ch in '\'"`':
                            # crude: skip nested literal via recursive call on substring
                            sub=lex_one(src,m); out.extend(sub[0]); m=sub[1]; continue
                        if ch=='{': d+=1
                        elif ch=='}': d-=1
                        m+=1
                    buf.append('\x00%d\x00'%k); k+=1; j=m; continue
                buf.append(src[j]); j+=1
            out.append(('t',''.join(buf),i,j+1)); i=j+1; prev='a'; continue
        if c=='/':
            # regex literal?
            if prev in '' or prev in '(,=:[!&|?{};+-*%<>~^' :
                j=i+1;cls=False
                while j<n:
                    ch=src[j]
                    if ch=='\\': j+=2; continue
                    if ch=='[': cls=True
                    elif ch==']': cls=False
                    elif ch=='/' and not cls: break
                    elif ch=='\n': break
                    j+=1
                i=j+1
                while i<n and src[i].isalpha(): i+=1
                prev='a'; continue
        if not c.isspace():
            prev = c if not (c.isalnum() or c in '_$') else 'a'
            # keywords like return/typeof before regex
            if prev=='a':
                m=re.match(r'[A-Za-z_$][\w$]*',src[i:])
                if m:
                    w=m.group(0); i+=len(w); prev='' if w in('return','typeof','case','in','of','do','else') else 'a'; continue
        i+=1
    return out
def lex_one(src,i):
    c=src[i];n=len(src)
    if c in '\'"':
        j=i+1
        while j<n and src[j]!=c:
            j+= 2 if src[j]=='\\' else 1
        return ([('s',src[i+1:j],i,j+1)],j+1)
    # template
    # find end of first template
    j=i+1
    d=0
    while j<n:
        if src[j]=='\\': j+=2; continue
        if src[j]=='`' and d==0: break
        if src[j]=='$' and src[j+1]=='{': d+=1; j+=2; continue
        if src[j]=='}' and d>0: d-=1
        j+=1
    inner=lex(src[i:j+1])
    return (inner,j+1)
