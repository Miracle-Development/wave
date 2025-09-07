import 'package:wave/redux/actions.dart';
import 'package:wave/redux/state.dart';

AppState appReducer(AppState state, dynamic action) {
  if (action is UpdateTimerAction) {
    return state.copyWith(timerValue: state.timerValue + 1);
  }

  return state;
}
