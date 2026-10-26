D='/tmp/claude-0/-home-claude/48139c96-bba5-5f11-817b-eff5cbec6670/scratchpad/occ/data/dictionary/'
def load(*fs):
    m={}
    for f in fs:
        for line in open(D+f,encoding='utf8'):
            if not line.strip() or line.startswith('#'): continue
            k,v=line.rstrip('\n').split('\t'); m.setdefault(k,v.split(' ')[0])
    return m
ST=load('STPhrases.txt','STCharacters.txt'); TWP=load('TWPhrases.txt'); TWV=load('TWVariants.txt')
def mm(s,d,ml):
    out=[];i=0
    while i<len(s):
        for L in range(min(ml,len(s)-i),0,-1):
            w=s[i:i+L]
            if w in d: out.append(d[w]); i+=L; break
        else: out.append(s[i]); i+=1
    return ''.join(out)
MLS=max(map(len,ST));MLP=max(map(len,TWP))
FIX={'小滿':'小滿','面容 ID':'Face ID'}
def conv(s):
    s=mm(s,ST,MLS); s=mm(s,TWP,MLP); s=''.join(TWV.get(c,c) for c in s)
    return s
if __name__=='__main__':
    print(conv('小满记 打卡 软件 设置 默认 视频 信息 鼠标 内存 激活 搜索 文件 网络 账户 屏幕 面容 ID 菜单 撤销 回忆 笔记 头像 图标 小组件 打卡日志 程序 用户 支持 质量 数据 导入 导出 备份 云盘 相册 照片 只 里 后 着'))
