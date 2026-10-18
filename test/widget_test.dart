import 'package:flutter_test/flutter_test.dart';
import 'package:touchline/data/models.dart';

void main() {
  test('team short codes', () {
    expect(Team.defaultShort('Mamba Point Rovers'), 'MPR');
    expect(Team.defaultShort('Kakata'), 'KAK');
    expect(Team.defaultShort('Sinkor United'), 'SIU');
  });
}
