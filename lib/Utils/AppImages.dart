class AppImages {
  AppImages._(); // Private constructor to prevent instantiation

  static const svg = _Svg();
  static const images = _Images();
}

class _Svg {
  const _Svg();

  final String logo = 'assets/svgs/logo.svg';
  final String authcover = 'assets/svgs/authcover.svg';
}

class _Images {
  const _Images();

  final String authcover = 'assets/images/authcover.png';
  final String logo = 'assets/images/logo.png';
  final String logocolored = 'assets/images/logocolored.png';
}
