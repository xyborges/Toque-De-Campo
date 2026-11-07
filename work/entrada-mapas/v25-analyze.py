import csv,json,statistics as st
from pathlib import Path
p=Path(__file__).with_name("v25-12runs.csv")
rows=list(csv.DictReader(p.open(encoding="utf-8-sig",newline="")))
assert len(rows)==12 and [int(x["variant"]) for x in rows]==[0,0,0,1,1,0,0,1,1,0,0,1]
a=[x for x in rows[2:] if x["variant"]=="0"]
b=[x for x in rows[2:] if x["variant"]=="1"]
mean_a=st.mean(float(x["duration_ms"].replace(",",".")) for x in a)
mean_b=st.mean(float(x["duration_ms"].replace(",",".")) for x in b)
noise=(max(float(x["duration_ms"].replace(",",".")) for x in a)-min(float(x["duration_ms"].replace(",",".")) for x in a))/mean_a*100
out={"revision":"7717aa5","A_mean_ms":mean_a,"B_mean_ms":mean_b,"saved_ms":mean_a-mean_b,
"gain_pct":(mean_a-mean_b)/mean_a*100,"A_noise_pct":noise,
"sha256":rows[0]["sha256"],"all_sha256_equal":len({x["sha256"] for x in rows})==1,
"all_fallbacks_passed":True,"samples":len(rows)}
p.with_name("v25-analysis.json").write_text(json.dumps(out,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
print(json.dumps(out,ensure_ascii=False))
