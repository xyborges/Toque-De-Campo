extends SceneTree
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func run() -> void:
	var server:=GameMatchStats.new();var client:=GameMatchStats.new()
	for team in [0,1]:
		for slot in 15:
			server.register(1000+team*100+slot,"Human" if slot==0 else "Bot",team)
	var snapshot:=server.snapshot();client.receive(snapshot)
	check(client.rows.size()==30,"all30participants retained")
	var teams:=[0,0];var bots:=[0,0];var humans:=[0,0]
	for row: Dictionary in client.rows.values():
		teams[int(row.team)]+=1
		if row.name=="Human":humans[int(row.team)]+=1
		else:bots[int(row.team)]+=1
	check(teams==[15,15] and bots==[14,14] and humans==[1,1],"two fullteams14bots+1human preserved")
	for id in 10:server.register(2000+id,"Extra",id%2)
	client.receive(server.snapshot());check(client.rows.size()==40,"40participants retained")
	server.rows[1105].points=700;server.rows[1105].kills=7
	client.receive(server.snapshot());check(client.rows[1105].points==700 and client.rows[1105].kills==7,"score refresh preserved")
	var excess: Array=[]
	for id in 160:excess.append({"id":id+1,"points":id,"team":id%2})
	client.receive(excess);check(client.rows.size()==GameMatchStats.MAX_ROWS,"128row defensivebound")
	check(client.rows.has(128) and not client.rows.has(129),"entries beyond bound ignored")
	excess.append({"id":5,"points":9999,"team":1});client.receive(excess)
	check(client.rows.size()==GameMatchStats.MAX_ROWS and client.rows[5].points==9999,"duplicate updates existing row at capacity")
	var invalid: Array=[{},null,"bad",{"points":3},{"id":"12"},{"id":-1},{"id":0},{"id":1.5}]
	client.receive(invalid);check(client.rows.is_empty(),"missing invalid and nonpositiveIDs skipped")
	invalid.append({"id":3,"points":2});invalid.append({"id":3,"points":4});client.receive(invalid)
	check(client.rows.size()==1 and client.rows[3].points==4,"duplicateIDs do not consume extra capacity")
	var original: Dictionary={"id":4,"points":10,"nested":{"value":1}}
	client.receive([original]);original.nested.value=2
	check(client.rows[4].nested.value==1,"receiveddata copied independently")
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Isolated scoreboard ingestion at30/40/128participants, two teams14bots+1human, duplicates at capacity, malformed IDs and score refresh. Does not change actual bot population or network protocol."}
	NavalStorage.write_json("res://work/match-stats-capacity1103.json",report);print("MATCH_STATS_CAPACITY1103 ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
