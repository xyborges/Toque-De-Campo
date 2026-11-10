#include "pose_math.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <gdextension_interface.h>
using namespace godot;
static void initialize_war_pose(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) GDREGISTER_CLASS(WarNativePoseMath);
}
static void uninitialize_war_pose(ModuleInitializationLevel level) {
    (void)level;
}
extern "C" GDExtensionBool GDE_EXPORT war_pose_math_init(
    GDExtensionInterfaceGetProcAddress get_proc_address,
    GDExtensionClassLibraryPtr library,
    GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc_address, library, initialization);
    init.register_initializer(initialize_war_pose);
    init.register_terminator(uninitialize_war_pose);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
