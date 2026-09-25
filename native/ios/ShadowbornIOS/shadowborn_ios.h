#pragma once

#include "core/object/object.h"
#include "core/string/ustring.h"
#include "core/variant/dictionary.h"

#ifdef __OBJC__
@class ShadowbornHapticEngine;
typedef ShadowbornHapticEngine ShadowbornHapticEngineRef;
#else
typedef void ShadowbornHapticEngineRef;
#endif

class ShadowbornIOS : public Object {
	GDCLASS(ShadowbornIOS, Object);

	static ShadowbornIOS *instance;
	ShadowbornHapticEngineRef *haptic_engine = nullptr;

protected:
	static void _bind_methods();

public:
	static ShadowbornIOS *get_singleton();

	int get_thermal_state() const;
	bool is_low_power_mode_enabled() const;
	bool supports_haptics() const;
	void play_haptic(const String &event_id, double intensity);
	Dictionary get_native_diagnostics() const;

	ShadowbornIOS();
	~ShadowbornIOS();
};
