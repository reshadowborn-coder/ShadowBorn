#include "shadowborn_ios_module.h"

#include "core/config/engine.h"
#include "core/os/memory.h"

#include "shadowborn_ios.h"

static ShadowbornIOS *shadowborn_ios_singleton = nullptr;

void shadowborn_ios_init() {
	if (shadowborn_ios_singleton != nullptr) {
		return;
	}
	shadowborn_ios_singleton = memnew(ShadowbornIOS);
	Engine::get_singleton()->add_singleton(
			Engine::Singleton("ShadowbornIOS", shadowborn_ios_singleton));
}

void shadowborn_ios_deinit() {
	if (shadowborn_ios_singleton != nullptr) {
		Engine *engine = Engine::get_singleton();
		if (engine != nullptr && engine->has_singleton("ShadowbornIOS")) {
			// Remove the registry pointer before deleting the Object so plugin
			// teardown can never leave a dangling Engine singleton reference.
			engine->remove_singleton("ShadowbornIOS");
		}
		memdelete(shadowborn_ios_singleton);
		shadowborn_ios_singleton = nullptr;
	}
}
