from pathlib import Path
home=Path(__file__).resolve().parents[3]
a=home/"Toque-De-Campo-ia2-architecture-cache"/"modes/war/scripts/favela_map.gd"
b=home/"Toque-De-Campo-ia2-v25-cache-20261107"/"modes/war/scripts/favela_map.gd"
source=a.read_text(encoding="utf-8")
start=source.index("# IA2 experimental plan cache.")
end=source.index("static func ia2_terrain_digest(",start)
cache=source[start:end]
original=b.read_text(encoding="utf-8")
old="""static func housing_plan() -> Array[Dictionary]:
\tif housing_lots.is_empty():
\t\thousing_lots=LAYOUT.generate(road_envelopes(),BASES_2D,OBJECTIVES_2D)
\treturn housing_lots
"""
assert original.count(old)==1
original=original.replace(old,cache,1)
b.write_text(original,encoding="utf-8",newline="\n")
print("V25_HOUSING_FLAG_IMPORTED",len(cache))
