class AppState {
  final int timerValue;

  const AppState({required this.timerValue});

  AppState.initialState() : timerValue = 0;

  AppState copyWith({
    int? timerValue,
  }) {
    return AppState(
      timerValue: timerValue ?? this.timerValue,
    );
  }
}
