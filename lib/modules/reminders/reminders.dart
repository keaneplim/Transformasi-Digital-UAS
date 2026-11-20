/// Module `reminders` (level 4, owner B scheduler + closing / C hydration) — public front door.
///
/// ReminderScheduler + Reminder strategies: ClosingReminder (A03, uses routing's TimeBudget),
/// HydrationReminder (F08 d). Returns E10 ReminderDue for the caller to publish and show (UI13).
/// Not built yet: final call (UC-A03-2), voice (needs TTS, F04), system notification.
/// Spec: IMPLEMENTATION_PLAN.md A03, F08(d). Template: docs/engineering/ARCHITECTURE.md §7.
library;

export 'src/data/reminder_store.dart';
export 'src/domain/reminder.dart';
export 'src/domain/reminder_scheduler.dart';
