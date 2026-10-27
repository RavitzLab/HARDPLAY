#!/usr/bin/env python3
"""Build renamed OFL derivatives. Requires FontTools 4.60.1 as a build-only tool."""
from pathlib import Path
from copy import deepcopy
import hashlib, json
from fontTools.ttLib import TTFont, newTable
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen

ROOT=Path(__file__).resolve().parents[2]
ASSETS=ROOT/'assets/fonts'
WEIGHTS={'Regular':400,'Medium':500,'Semibold':600}

def static(source,weight):
    f=TTFont(ASSETS/source,recalcTimestamp=False)
    if 'fvar' in f:
        axes={a.axisTag:(weight if a.axisTag=='wght' else a.defaultValue) for a in f['fvar'].axes}
        f=instantiateVariableFont(f,axes,inplace=True)
    return f

def outline(glyphset,name,scale,dx):
    recording=DecomposingRecordingPen(glyphset)
    glyphset[name].draw(recording)
    pen=TTGlyphPen(None)
    recording.replay(TransformPen(pen,(scale,0,0,1,dx,0)))
    return pen.glyph()

def remake(f,scale,tracking,mono):
    glyphset=f.getGlyphSet();old=deepcopy(f['hmtx'].metrics)
    new={}
    for name in f.getGlyphOrder():
        advance,lsb=old[name]
        dx=(advance*(1-scale)/2) if mono else tracking/2
        g=outline(glyphset,name,scale,dx);new[name]=g
        g.recalcBounds(f['glyf'])
        width=advance if mono else (round(advance*scale+tracking) if advance else 0)
        f['hmtx'].metrics[name]=(width,round(getattr(g,'xMin',0)))
    f['glyf'].glyphs=new
    # Preserve original kerning/positioning while matching the slight horizontal scaling.
    visited=set()
    def positions(value):
        if id(value) in visited:return
        visited.add(id(value))
        if hasattr(value,'__dict__'):
            for key,item in list(vars(value).items()):
                if key in ('XAdvance','XPlacement') and isinstance(item,int):setattr(value,key,round(item*scale))
                elif not key.startswith('_'):positions(item)
        elif isinstance(value,(list,tuple)):
            for item in value:positions(item)
        elif isinstance(value,dict):
            for item in value.values():positions(item)
    if 'GPOS' in f:positions(f['GPOS'].table)
    if 'kern' in f:
        for table in f['kern'].kernTables:
            if hasattr(table,'kernTable'):table.kernTable={k:round(v*scale) for k,v in table.kernTable.items()}

def fill_cyrillic(f,donor,scale,tracking):
    cmap=f.getBestCmap();other=donor.getBestCmap();glyphset=donor.getGlyphSet()
    added={};order=f.getGlyphOrder()
    ratio=f['head'].unitsPerEm/donor['head'].unitsPerEm
    assert ratio==1,'Sources should use the same UPM for this recipe'
    for code,name in other.items():
        if code in cmap or not (0x400<=code<=0x52f or 0xA640<=code<=0xA69F):continue
        target='hpCYR_'+format(code,'04X')
        g=outline(glyphset,name,scale,tracking/2);g.recalcBounds(f['glyf'])
        f['glyf'].glyphs[target]=g;order.append(target)
        advance=donor['hmtx'].metrics[name][0]
        f['hmtx'].metrics[target]=(round(advance*scale+tracking) if advance else 0,round(getattr(g,'xMin',0)))
        added[code]=target
    f.setGlyphOrder(order)
    for table in f['cmap'].tables:
        if table.isUnicode():table.cmap.update(added)
    return len(added)

def rename(f,family,style,weight,copyright_text,license_text,recipe):
    names=newTable('name');names.names=[];f['name']=names
    ps=family.replace(' ','')+'-'+style
    records={0:copyright_text+'\nModifications copyright 2026 RavitzLab.',1:family,2:style,3:ps+';1.000;RavitzLab',4:family+' '+style,5:'Version 1.000',6:ps,8:'RavitzLab (modified version)',9:'Original OFL authors; proportion and spacing adaptations by RavitzLab',10:recipe,11:'https://github.com/RavitzLab/HARDPLAY',13:license_text,14:'https://openfontlicense.org',16:family,17:style,21:family,22:style}
    for key,value in records.items():
        names.setName(value,key,3,1,0x409)
        # Mac Roman is sufficient for these public English family names; license remains Unicode.
        if key!=13:names.setName(value,key,1,0,0)
    if 'STAT' in f:del f['STAT']
    if 'DSIG' in f:del f['DSIG']
    f['OS/2'].usWeightClass=weight
    f['OS/2'].fsSelection &= ~(1<<0 | 1<<5 | 1<<6)
    if weight==400:f['OS/2'].fsSelection |= 1<<6
    f['head'].macStyle=0;f['head'].modified=3875904000
    f['hhea'].advanceWidthMax=max(v[0] for v in f['hmtx'].metrics.values())
    return ps

def main():
    recipes=[('Hardplay Sans','HP-PlexSans.ttf','HP-PlexSans-OFL.txt',0.975,14,False),('Hardplay Grid','HP-SpaceGrotesk.ttf','HP-SpaceGrotesk-OFL.txt',1.04,8,False),('Hardplay Mono','HP-JetBrainsMono.ttf','HP-JetBrainsMono-OFL.txt',0.955,0,True)]
    manifest=[]
    for family,source,license_file,scale,tracking,mono in recipes:
        license_text=(ASSETS/license_file).read_text()
        if family=='Hardplay Grid':license_text+='\n\n'+(ASSETS/'HP-PlexSans-OFL.txt').read_text()
        copyright_text='\n'.join(line for line in license_text.splitlines() if line.startswith('Copyright'))
        recipe=f'OFL derivative: {source}; x-scale={scale}; tracking={tracking} units; monospace advances preserved={mono}. Original commercial font files are not used.'
        (ASSETS/(family.replace(' ','')+'-OFL.txt')).write_text(license_text+'\n\nModifications copyright 2026 RavitzLab. '+recipe+'\n')
        for style,weight in WEIGHTS.items():
            f=static(source,weight);remake(f,scale,tracking,mono)
            added=fill_cyrillic(f,static('HP-PlexSans.ttf',weight),scale,tracking) if family=='Hardplay Grid' else 0
            ps=rename(f,family,style,weight,copyright_text,license_text,recipe)
            target=ASSETS/(ps+'.ttf');f.save(target)
            check=TTFont(target,checkChecksums=2)
            cmap=check.getBestCmap()
            assert all(ord(c) in cmap for c in 'HARDPLAY0123456789АБВГДЕЁЖЗабвгдеёжз')
            assert check['name'].getDebugName(6)==ps and 'fvar' not in check
            if mono:assert len({check['hmtx'].metrics[cmap[ord(c)]][0] for c in 'HARDPLAY0123456789АБВГДЕЁЖЗ'})==1
            manifest.append({'file':target.name,'family':family,'style':style,'source':source,'weight':weight,'x_scale':scale,'tracking':tracking,'cyrillic_added':added,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'bytes':target.stat().st_size})
            print(ps,target.stat().st_size,'bytes; Cyrillic added:',added,flush=True)
    (ASSETS/'Hardplay-fonts.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
if __name__=='__main__':main()
