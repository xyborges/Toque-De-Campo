from pathlib import Path
root=Path(__file__).resolve().parents[2]
p=root/'modes/war/scripts/favela_map.gd'
s=p.read_text(encoding='utf-8')
def repl(a,b):
    global s
    assert s.count(a)==1,(a[:85],s.count(a))
    s=s.replace(a,b,1)
repl('func _neighborhoods(k: EnvironmentKit) -> Dictionary:\n\tvar count:=0',
'''func _neighborhoods(k: EnvironmentKit) -> Dictionary:
\tvar ia2_subprofile:=OS.get_environment("TDC_IA2_NEIGHBOR_SUBSTAGES")=="1"
\tvar ia2_ground_usec:=0
\tvar ia2_house_usec:=0
\tvar ia2_shops_usec:=0
\tvar count:=0''')
repl('\tfor lot: Dictionary in housing_plan():\n\t\tvar p: Vector2=lot.position\n\t\tvar size: Vector2=lot.size',
'''\tfor lot: Dictionary in housing_plan():
\t\tvar ia2_at:=Time.get_ticks_usec() if ia2_subprofile else 0
\t\tvar p: Vector2=lot.position
\t\tvar size: Vector2=lot.size''')
repl('\t\tvar adjacent:=not previous_lot.is_empty()',
'''\t\tif ia2_subprofile:ia2_ground_usec+=Time.get_ticks_usec()-ia2_at
\t\tvar adjacent:=not previous_lot.is_empty()''')
repl('\t\t_house(k,base,size.x,size.y,storeys,lot.finish,count,open_house,base.y-min_ground+.35,upper_storeys,lot)\n',
'''\t\tvar ia2_house_at:=Time.get_ticks_usec() if ia2_subprofile else 0
\t\t_house(k,base,size.x,size.y,storeys,lot.finish,count,open_house,base.y-min_ground+.35,upper_storeys,lot)
\t\tif ia2_subprofile:ia2_house_usec+=Time.get_ticks_usec()-ia2_house_at
''')
repl('\tfor site: Dictionary in shop_sites:\n\t\t_commercial_front(k, site.base, site.half, site.index, site.lot)\n',
'''\tvar ia2_shops_at:=Time.get_ticks_usec() if ia2_subprofile else 0
\tfor site: Dictionary in shop_sites:
\t\t_commercial_front(k, site.base, site.half, site.index, site.lot)
\tif ia2_subprofile:
\t\tia2_shops_usec+=Time.get_ticks_usec()-ia2_shops_at
\t\tset_meta("ia2_neighbor_substages_ms",{
\t\t\t"ground_center_and_corners":ia2_ground_usec*.001,
\t\t\t"house":ia2_house_usec*.001,
\t\t\t"commercial_fronts":ia2_shops_usec*.001,
\t\t\t"houses":count,"shops":shop_sites.size()})\n''')
repl('\t\tbuild_metrics["ia2_stage_times_ms"]=ia2_stages\n',
'''\t\tbuild_metrics["ia2_stage_times_ms"]=ia2_stages
\t\tbuild_metrics["ia2_neighborhood_substages"]=get_meta("ia2_neighbor_substages_ms",{})\n''')
p.write_text(s,encoding='utf-8',newline='\n')
t=root/'tests/ia2_housing_plan_cache_qa.gd'
x=t.read_text(encoding='utf-8')
assert x.count('"stages":metrics.get("ia2_stage_times_ms",{}),')==1
x=x.replace('"stages":metrics.get("ia2_stage_times_ms",{}),',
            '"stages":metrics.get("ia2_stage_times_ms",{}),\n\t\t"neighbor_substages":metrics.get("ia2_neighborhood_substages",{}),')
t.write_text(x,encoding='utf-8',newline='\n')
print("PROFILE_NEIGHBORHOODS_INSERTED")
