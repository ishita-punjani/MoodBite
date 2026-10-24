/// Diet filter for recommendations. Veg and non-veg are strict filters.
enum Diet {
  any('any', 'Any'),
  veg('veg', 'Veg'),
  nonVeg('nonveg', 'Non-veg');

  const Diet(this.wireValue, this.label);

  /// Value sent to the server (`p_diet`).
  final String wireValue;
  final String label;

  /// Profile `is_veg`: null = no preference, true = veg only, false = non-veg only.
  static Diet fromProfile(bool? isVeg) => switch (isVeg) {
        null => any,
        true => veg,
        false => nonVeg,
      };

  bool allows(bool dishIsVeg) => switch (this) {
        any => true,
        veg => dishIsVeg,
        nonVeg => !dishIsVeg,
      };
}
