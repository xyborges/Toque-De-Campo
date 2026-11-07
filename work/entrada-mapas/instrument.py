from pathlib import Path
root=Path(__file__).resolve().parents[2]
path=root/'modes/war/scripts/favela_map.gd'
s=path.read_text(encoding='utf-8')
def replace_once(a,b):
    global s
    if s.count(a)!=1:
        raise RuntimeError(f"expected exactly one target, found {s.count(a)}: {a[:85]}")
    s=s.replace(a,b,1)
replace_once("func build() -> void:\n\tvar begun:=Time.get_ticks_msec()",
"""static func _ia2_stage_stamp(stages: Dictionary,key: String,start_us: int) -> int:
\tvar now:=Time.get_ticks_usec()
\tstages[key]=roundf((now-start_us)*.001*1000.)*.001
\treturn now

func build() -> void:
\tvar begun:=Time.get_ticks_msec()
\tvar ia2_stage_profile:=OS.get_environment("TDC_IA2_MAP_STAGES")=="1"
\tvar ia2_stages: Dictionary={}
\tvar ia2_stage_at:=Time.get_ticks_usec()""")
replace_once("\t_reserve_buildings_and_spawns()\n",
    '\t_reserve_buildings_and_spawns()\n\tif ia2_stage_profile:ia2_stage_at=_ia2_stage_stamp(ia2_stages,"layout_reservations",ia2_stage_at)\n')
replace_once('\tfor iz in 15:\n\t\tfor ix in 15:_terrain_tile(ix,iz)\n',
    '\tfor iz in 15:\n\t\tfor ix in 15:_terrain_tile(ix,iz)\n\tif ia2_stage_profile:ia2_stage_at=_ia2_stage_stamp(ia2_stages,"terrain_tiles",ia2_stage_at)\n')
replace_once("\t_bases(kit)\n",
    '\t_bases(kit)\n\tif ia2_stage_profile:ia2_stage_at=_ia2_stage_stamp(ia2_stages,"kit_and_bases",ia2_stage_at)\n')
replace_once("\tvar neighborhood:=_neighborhoods(kit)\n",
    '\tvar neighborhood:=_neighborhoods(kit)\n\tif ia2_stage_profile:ia2_stage_at=_ia2_stage_stamp(ia2_stages,"neighborhoods",ia2_stage_at)\n')
replace_once("\tvar edge_summary:=_edge_infrastructure(kit)\n",
    '\tvar edge_summary:=_edge_infrastructure(kit)\n\tif ia2_stage_profile:ia2_stage_at=_ia2_stage_stamp(ia2_stages,"edge",ia2_stage_at)\n')
replace_once("\tBAILE.start(baile,render_visuals)\n",
    '\tBAILE.start(baile,render_visuals)\n\tif ia2_stage_profile:ia2_stage_at=_ia2_stage_stamp(ia2_stages,"baile",ia2_stage_at)\n')
replace_once("\t_urban_clutter(kit)\n",
    '\t_urban_clutter(kit)\n\tif ia2_stage_profile:ia2_stage_at=_ia2_stage_stamp(ia2_stages,"landmarks_wiring_clutter",ia2_stage_at)\n')
replace_once("\t_vegetation(kit)\n",
    '\t_vegetation(kit)\n\tif ia2_stage_profile:ia2_stage_at=_ia2_stage_stamp(ia2_stages,"vegetation_and_litter",ia2_stage_at)\n')
replace_once("\tkit.flush()\n",
    '\tif ia2_stage_profile:ia2_stage_at=_ia2_stage_stamp(ia2_stages,"hillside",ia2_stage_at)\n\tkit.flush()\n\tif ia2_stage_profile:ia2_stage_at=_ia2_stage_stamp(ia2_stages,"kit_flush",ia2_stage_at)\n')
replace_once('\tset_meta("favela_build_metrics",build_metrics)\n',
    '\tif ia2_stage_profile:\n\t\t_ia2_stage_stamp(ia2_stages,"finalization",ia2_stage_at)\n\t\tbuild_metrics["ia2_stage_times_ms"]=ia2_stages\n\tset_meta("favela_build_metrics",build_metrics)\n')
path.write_text(s,encoding='utf-8',newline='\n')
qa=root/'tests/ia2_housing_plan_cache_qa.gd'
q=qa.read_text(encoding='utf-8')
assert q.count('"collisions":metrics.get("collision_shapes",0),')==1
q=q.replace('"collisions":metrics.get("collision_shapes",0),',
            '"collisions":metrics.get("collision_shapes",0),\n\t\t"stages":metrics.get("ia2_stage_times_ms",{}),')
qa.write_text(q,encoding='utf-8',newline='\n')
print("INSTRUMENT_DONE",len(s))
