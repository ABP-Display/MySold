import unittest
from investment_categories import validate_categories, category_ids, DEFAULT_IDS


def category(ident='other', name='Autres'):
    return dict(id=ident, name=name, color=0xff77b8ae, icon=0xe047)


class InvestmentCategoryTests(unittest.TestCase):
    def test_defaults_remain_available_without_configuration(self):
        self.assertEqual(category_ids({}), DEFAULT_IDS)
        self.assertEqual(category_ids(None), DEFAULT_IDS)

    def test_names_colors_icons_and_custom_ids_round_trip(self):
        items = [category(), category('a' * 32, ' Métaux précieux ')]
        parsed = validate_categories(items)
        self.assertEqual(parsed[1]['name'], 'Métaux précieux')
        self.assertEqual(category_ids({'investmentCategories': parsed}), {'other', 'a' * 32})
        self.assertEqual(parsed[1]['color'], items[1]['color'])

    def test_invalid_payloads_and_reserved_fallback_are_rejected(self):
        for items in [None, {}, [], [category('stock')], [category()] * 41,
                      [category(), category('../user')], [category(), category('all')],
                      [category(), {**category('a' * 32), 'url': 'https://example.test'}]]:
            with self.subTest(items=items), self.assertRaises(ValueError):
                validate_categories(items)

    def test_duplicate_names_ids_and_empty_names_are_rejected(self):
        for item in [category(), category('a' * 32, ' autres '), category('a' * 32, ' '),
                     category('a' * 32, 'x' * 61)]:
            with self.subTest(item=item), self.assertRaises(ValueError):
                validate_categories([category(), item])

    def test_color_and_icon_types_and_ranges_are_enforced(self):
        for field, value in [('color', True), ('color', -1), ('color', 0xffffff),
                             ('color', 0x100000000), ('icon', True), ('icon', -1),
                             ('icon', 0x110000), ('icon', 0xd800), ('icon', 'script')]:
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                validate_categories([{**category(), field: value}])
