// sweep.h
// Adds an angular turn rate for continuously-firing weapons to turn along a smooth path.
// Optimized for a weapon low to the ground to carve a predictable slice through the air,
// somewhat above ground-level, assuming relatively low slope and wide unit firing angle.

// CONFIGURATION

#ifndef SWEEP_AIMX
	#define SWEEP_AIMX aimx1
#endif

#ifndef SWEEP_AIMY
	#define SWEEP_AIMY aimy1
#endif

#ifndef SWEEP_PIECE
	#define SWEEP_PIECE flare
#endif

#ifndef SWEEP_SPEED
	#define SWEEP_SPEED 30
#endif

#ifndef SWEEP_PITCH_MOD
	#define SWEEP_PITCH_MOD 2 // TODO: Any better way of doing this
#endif

// UTILITIES

#ifndef GET_ABS
	#define GET_ABS get 133 // GET_ABS(input)
#endif

#ifndef GET_MAX
	#define GET_MAX get 132 // GET_MAX(input)
#endif

#ifndef GET_SQRT
	#define GET_SQRT get 138 // GET_SQRT(input)
#endif

#ifndef WRAPDELTA
	#define WRAPDELTA(ang) (((ang + 98280) % 65520) - 32760)
#endif

#ifndef GAME_SPEED
	#define GAME_SPEED 30
#endif

// SWEEP CODE

static-var inTargetSwap;
static-var headingLast, pitchLast, deltaHeadingLast, deltaPitchLast, deltaAngleLastSq;

// High pitch responses look awful especially when the turret/chassis are in a counter-rotation.
// Give very slow pitch response, heavily dampened for larger angles, when not firing on-target.
#define SWEEP_STEP SWEEP_SPEED * GAME_SPEED * 0.1111  // Turn pitch should be nearly full speed.
#define SWEEP_LONG SWEEP_SPEED * GAME_SPEED * 0.3333  // Turn pitch should be very, very smooth.
#define SWEEP_STOP SWEEP_SPEED * GAME_SPEED * 0.6666  // Probably should not be pitching at all.

static-var sweepPitchMod; // (integer) divisor for pitch speed relative to overall angular speed
#define SWEEP_SPEED_PITCH() SWEEP_SPEED / (GET_MAX(sweepPitchMod, (deltaAngleLastSq + SWEEP_SPEED) / (GET_ABS(deltaPitchLast) + SWEEP_SPEED)))
#define SWEEP_SPEED_HEADING() GET_SQRT(SWEEP_SPEED * SWEEP_SPEED - SWEEP_SPEED * SWEEP_SPEED / sweepPitchMod / sweepPitchMod);

// Replaces some of the AimWeaponX method body. For example:
//
// AimWeapon1(heading, pitch)
// {
//      signal SIGNAL_AIM1;
//      set-signal-mask SIGNAL_AIM1;
//      call-script Sweep_AimWeapon(heading, pitch);
//      if (NOT inTargetSwap) return (TRUE);
//      wait-for-turn SWEEEP_AIMX around x-axis;
//      wait-for-turn SWEEEP_AIMY around y-axis;
//      return (TRUE);
// }
Sweep_AimWeapon(heading, pitch)
{
	deltaHeadingLast = WRAPDELTA(heading - headingLast);
	deltaPitchLast   = WRAPDELTA(  pitch -   pitchLast);
	deltaAngleLastSq = deltaHeadingLast * deltaHeadingLast + deltaPitchLast * deltaPitchLast;

	if (deltaAngleLastSq < SWEEP_STEP * SWEEP_STEP)
	{
		inTargetSwap = FALSE;

		if (deltaAngleLastSq < SWEEP_SPEED * SWEEP_PITCH_MOD)
		{
			sweepPitchMod = SWEEP_PITCH_MOD; // Use full pitch speed to keep time-on-target.
		}
		else
		{
			sweepPitchMod = SWEEP_PITCH_MOD + 1; // Move pitch smoothly and reduce aim snap.
		}
	}
	else
	{
		inTargetSwap = TRUE;

		if (deltaAngleLastSq < SWEEP_LONG * SWEEP_LONG)
		{
			sweepPitchMod = SWEEP_PITCH_MOD * 4;
		}
		else if (deltaAngleLastSq < SWEEP_STOP * SWEEP_STOP)
		{
			sweepPitchMod = SWEEP_PITCH_MOD * 5;
		}
		else if (GET_ABS(deltaHeadingLast) > GET_ABS(deltaPitchLast))
		{
			sweepPitchMod = SWEEP_SPEED * 2; // Stupid way to set pitch speed to zero.
		}
		else
		{
			sweepPitchMod = SWEEP_PITCH_MOD * 4;
		}
	}

	turn SWEEP_AIMY to y-axis heading  speed SWEEP_SPEED_HEADING();
	turn SWEEP_AIMX to x-axis pitch*-1 speed SWEEP_SPEED_PITCH();

	headingLast = heading;
	pitchLast = pitch;
}

Sweep_Reset()
{
	inTargetSwap = FALSE;
	headingLast = -100000;
	pitchLast = -100000;
	deltaHeadingLast = -100000;
	deltaPitchLast = -100000;
	deltaAngleLastSq = -100000;
}
