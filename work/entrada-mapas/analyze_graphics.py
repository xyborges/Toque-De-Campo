from pathlib import Path
import csv,json,statistics as st,sys
folder=Path(__file__).resolve().parent/"graphics"
for op in sys.argv[1:] or ("favela",):
    path=folder/f"{op}-graphics.csv"
    rows=list(csv.DictReader(path.open(encoding="utf-8",newline="")))
    pattern=[0,0,0,1,1,0,0,1,1,0,0,1]
    assert [int(row["variant"]) for row in rows]==pattern,(op,len(rows))
    assert all(int(row["bots"])==28 and int(row["focus_lost"])==0 and int(row["exit"])==0 for row in rows)
    pairs=[]
    for i in range(5):
        lhs,rhs=rows[2+i*2:4+i*2]
        a=lhs if lhs["variant"]=="0" else rhs
        b=rhs if lhs is a else lhs
        pairs.append((a,b))
    results={"operation":op,"runs":12,"control_AA":2,"AB_pairs":5}
    for key in ["ready_ms","world_ms","fps","p95_ms","p99_ms","max_ms","gpu_p99_ms","spike50","spike100"]:
        def val(row):return float(row[key])
        a=[val(x) for x,y in pairs]
        b=[val(y) for x,y in pairs]
        av,bv=st.mean(a),st.mean(b)
        aa0,aa1=val(rows[0]),val(rows[1])
        results[key]={"A":av,"B":bv,"A_minus_B":av-bv,
          "A_range_noise_pct":100*(max(a)-min(a))/av if av else None,
          "AA_noise_pct":100*abs(aa0-aa1)/st.mean((aa0,aa1)) if aa0+aa1 else None,
          "B_wins":sum(val(x)>val(y) for x,y in pairs) if key!="fps" else sum(val(x)<val(y) for x,y in pairs),
          "pairs":[round(val(x)-val(y),2) for x,y in pairs]}
    (folder/f"{op}-analysis.json").write_text(json.dumps(results,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    print("GRAPHICAL_ANALYSIS",json.dumps({key:results[key] for key in ("ready_ms","world_ms","fps","p99_ms","max_ms","spike100")},ensure_ascii=False))
