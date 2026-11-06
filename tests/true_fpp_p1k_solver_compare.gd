extends "res://tests/true_fpp_p1k_paired_cost.gd"
## Paired solver-only diagnostic. It does not certify the gameplay gate.
var reference: Script
var current_calibrations: Array=[]
var reference_calibrations: Array=[]
var current_inputs: Array=[]
var reference_inputs: Array=[]
var actors: Array[WarPlayer]=[]

func _batch(current: bool,tick: int) -> float:
 var started:=Time.get_ticks_usec()
 for index in ACTORS:
  var cadence:=2 if index<7 else (4 if index<21 else 8)
  var due: bool=(tick+index)%cadence==0
  var result: Dictionary
  if current:
   WarCollisionPoseSolver.capture(actors[index],current_inputs[index])
   result=WarCollisionPoseSolver.solve_cached(current_calibrations[index],current_inputs[index],due,true)
  else:
   reference.capture(actors[index],reference_inputs[index])
   result=reference.solve_cached(reference_calibrations[index],reference_inputs[index],due,true)
  if not result.get("supported",false):
   push_error("Solver diagnostic encountered unsupported state")
   quit(1)
 return float(Time.get_ticks_usec()-started)/1000.

func run() -> void:
 reference=load("res://work/p1k-opt-reference/collision_pose_solver.gd")
 game=Fixture.new()
 root.add_child(game)
 await process_frame
 for actor: WarPlayer in game.players.values():
  actor.set_process(false)
  actor.set_physics_process(false)
 for index in ACTORS:
  var actor:=game.make_actor(7200+index,false,1,"soldier",Vector3(index*4.,0,-30.)) as WarPlayer
  configure(actor,index,true)
  actors.append(actor)
  current_calibrations.append(WarCollisionPoseSolver.Calibration.from_dictionary(actor.p1g_collision_bindings))
  reference_calibrations.append(reference.Calibration.from_dictionary(actor.p1g_collision_bindings))
  current_inputs.append(WarCollisionPoseSolver.PoseInput.new())
  reference_inputs.append(reference.PoseInput.new())
 var old_samples: Array[float]=[]
 var new_samples: Array[float]=[]
 for tick in 480:
  await physics_frame
  for index in ACTORS:
   advance(actors[index],index,tick)
   actors[index].in_water()
  var old_time:=0.
  var new_time:=0.
  if tick%2==0:
   old_time=_batch(false,tick)
   new_time=_batch(true,tick)
  else:
   new_time=_batch(true,tick)
   old_time=_batch(false,tick)
  if tick>=120:
   old_samples.append(old_time)
   new_samples.append(new_time)
 old_samples.sort()
 new_samples.sort()
 print("P1K_SOLVER_COMPARE ",JSON.stringify({"samples":old_samples.size(),
  "old_p50_ms":old_samples[179],"new_p50_ms":new_samples[179],
  "old_p99_ms":old_samples[355],"new_p99_ms":new_samples[355]}))
 game.queue_free()
 await process_frame
 quit()
