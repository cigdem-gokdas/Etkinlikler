import 'package:etkinlik_kesif/features/onboarding/data/onboarding_repository.dart';

class MemoryOnboardingRepository implements OnboardingRepository {
  bool completed = false;
  int writes = 0;
  Future<void> Function()? onComplete;
  @override
  Future<bool> isCompleted() async => completed;
  @override
  Future<void> complete() async {
    writes++;
    await onComplete?.call();
    completed = true;
  }
}
