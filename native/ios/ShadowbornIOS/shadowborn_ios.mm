#include "shadowborn_ios.h"

#import <CoreHaptics/CoreHaptics.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include "core/object/class_db.h"

ShadowbornIOS *ShadowbornIOS::instance = nullptr;

@interface ShadowbornHapticEngine : NSObject
@property(nonatomic, strong) UIImpactFeedbackGenerator *lightGenerator;
@property(nonatomic, strong) UIImpactFeedbackGenerator *mediumGenerator;
@property(nonatomic, strong) UIImpactFeedbackGenerator *heavyGenerator;
- (BOOL)supportsHaptics;
- (void)playEvent:(NSString *)eventID intensity:(CGFloat)intensity;
@end

@implementation ShadowbornHapticEngine

- (instancetype)init {
	self = [super init];
	if (self) {
		_lightGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
		_mediumGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
		_heavyGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
		[_lightGenerator prepare];
		[_mediumGenerator prepare];
		[_heavyGenerator prepare];
	}
	return self;
}

- (BOOL)supportsHaptics {
	return [CHHapticEngine capabilitiesForHardware].supportsHaptics;
}

- (UIImpactFeedbackGenerator *)generatorForEvent:(NSString *)eventID {
	if ([eventID isEqualToString:@"guard_break"] ||
			[eventID isEqualToString:@"heavy_impact"] ||
			[eventID isEqualToString:@"summon_commit"]) {
		return self.heavyGenerator;
	}
	if ([eventID isEqualToString:@"ui_reject"] ||
			[eventID isEqualToString:@"guarded_contact"] ||
			[eventID isEqualToString:@"perfect_timing"] ||
			[eventID isEqualToString:@"rune_complete"]) {
		return self.mediumGenerator;
	}
	return self.lightGenerator;
}

- (void)playEvent:(NSString *)eventID intensity:(CGFloat)intensity {
	if (![self supportsHaptics]) {
		return;
	}
	CGFloat clampedIntensity = MIN(1.0, MAX(0.0, intensity));
	void (^performImpact)(void) = ^{
		UIImpactFeedbackGenerator *generator = [self generatorForEvent:eventID];
		[generator prepare];
		[generator impactOccurredWithIntensity:clampedIntensity];
		// Prime the same persistent generator for a likely subsequent contact.
		[generator prepare];
	};
	if ([NSThread isMainThread]) {
		performImpact();
	} else {
		dispatch_async(dispatch_get_main_queue(), performImpact);
	}
}

@end

void ShadowbornIOS::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_thermal_state"), &ShadowbornIOS::get_thermal_state);
	ClassDB::bind_method(D_METHOD("is_low_power_mode_enabled"), &ShadowbornIOS::is_low_power_mode_enabled);
	ClassDB::bind_method(D_METHOD("supports_haptics"), &ShadowbornIOS::supports_haptics);
	ClassDB::bind_method(D_METHOD("play_haptic", "event_id", "intensity"), &ShadowbornIOS::play_haptic);
	ClassDB::bind_method(D_METHOD("get_native_diagnostics"), &ShadowbornIOS::get_native_diagnostics);
}

ShadowbornIOS *ShadowbornIOS::get_singleton() {
	return instance;
}

ShadowbornIOS::ShadowbornIOS() {
	ERR_FAIL_COND(instance != nullptr);
	instance = this;
	haptic_engine = [[ShadowbornHapticEngine alloc] init];
}

ShadowbornIOS::~ShadowbornIOS() {
	haptic_engine = nil;
	if (instance == this) {
		instance = nullptr;
	}
}

int ShadowbornIOS::get_thermal_state() const {
	return (int)[NSProcessInfo processInfo].thermalState;
}

bool ShadowbornIOS::is_low_power_mode_enabled() const {
	return [NSProcessInfo processInfo].lowPowerModeEnabled;
}

bool ShadowbornIOS::supports_haptics() const {
	if (haptic_engine == nullptr) {
		return false;
	}
	return [(ShadowbornHapticEngine *)haptic_engine supportsHaptics];
}

void ShadowbornIOS::play_haptic(const String &event_id, double intensity) {
	if (haptic_engine == nullptr || event_id.is_empty()) {
		return;
	}
	NSString *event = [NSString stringWithUTF8String:event_id.utf8().get_data()];
	if (event == nil) {
		return;
	}
	[(ShadowbornHapticEngine *)haptic_engine playEvent:event intensity:(CGFloat)intensity];
}

Dictionary ShadowbornIOS::get_native_diagnostics() const {
	NSProcessInfo *process = [NSProcessInfo processInfo];
	UIDevice *device = [UIDevice currentDevice];

	Dictionary result;
	result["thermal_state"] = (int)process.thermalState;
	result["low_power_mode"] = (bool)process.lowPowerModeEnabled;
	result["supports_haptics"] = supports_haptics();
	result["processor_count"] = (int64_t)process.processorCount;
	result["active_processor_count"] = (int64_t)process.activeProcessorCount;
	result["physical_memory_bytes"] = (int64_t)process.physicalMemory;
	result["system_name"] = String::utf8(device.systemName.UTF8String != nullptr ? device.systemName.UTF8String : "");
	result["system_version"] = String::utf8(device.systemVersion.UTF8String != nullptr ? device.systemVersion.UTF8String : "");
	result["device_family"] = String::utf8(device.model.UTF8String != nullptr ? device.model.UTF8String : "");
	return result;
}
