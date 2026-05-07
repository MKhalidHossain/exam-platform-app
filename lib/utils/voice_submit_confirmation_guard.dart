class VoiceSubmitConfirmationGuard {
  bool _isPending = false;

  bool get isPending => _isPending;

  void requestSubmit() {
    _isPending = true;
  }

  bool confirmSubmit() {
    if (!_isPending) return false;
    _isPending = false;
    return true;
  }

  void clear() {
    _isPending = false;
  }
}
