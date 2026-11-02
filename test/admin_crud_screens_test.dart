// UC-08 — Admin category / product CRUD widget tests.
//
// The screens own their bloc, so the tests mount them with the fake
// catalogue service and assert what the admin sees and does:
//
//   1. the category list renders its rows and the search filters them,
//   2. the category form validates the name and saves the row,
//   3. the product list renders its rows and the category chips filter,
//   4. the product form validates the price and the category.

import 'package:delicia/domain/models/category.dart';
import 'package:delicia/domain/models/product.dart';
import 'package:delicia/domain/services/admin_catalog_service.dart';
import 'package:delicia/presentation/admin/categories/category_form_screen.dart';
import 'package:delicia/presentation/admin/categories/category_list_screen.dart';
import 'package:delicia/presentation/admin/products/product_form_screen.dart';
import 'package:delicia/presentation/admin/products/product_list_screen.dart';
import 'package:delicia/presentation/components/btn_frave.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_admin_services.dart';
import 'helpers/pump_helpers.dart';

Category _category({required String id, String name = 'Burger'}) {
  return Category(id: id, category: name, description: 'Món ngon');
}

Productsdb _product({
  required String id,
  String name = 'Burger',
  String categoryId = 'c1',
}) {
  return Productsdb(
    id: id,
    nameProduct: name,
    description: 'Ngon',
    price: 10,
    status: 1,
    picture: '',
    category: 'Burger',
    categoryId: categoryId,
  );
}

/// Gives the test a tall viewport so the whole form is laid out.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Mounts a screen with the fake catalogue + uploader.
Widget _harness(
  Widget child, {
  required AdminCatalogService catalogService,
  ImageUploadService? uploader,
}) {
  return MultiRepositoryProvider(
    providers: <RepositoryProvider<dynamic>>[
      RepositoryProvider<AdminCatalogService>.value(value: catalogService),
      RepositoryProvider<ImageUploadService>.value(
        value: uploader ?? FakeImageUploadService(),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: child,
    ),
  );
}

void main() {
  group('AdminCategoryListScreen', () {
    testWidgets('renders a row per category', (WidgetTester tester) async {
      final catalog = FakeAdminCatalogService(
        categories: <Category>[
          _category(id: 'c1', name: 'Burger'),
          _category(id: 'c2', name: 'Pizza'),
        ],
      );

      await tester.pumpWidget(
        _harness(
          const AdminCategoryListScreen(),
          catalogService: catalog,
        ),
      );
      await settleAdmin(tester);

      expect(find.text('Quản lý danh mục'), findsOneWidget);
      expect(find.text('Burger'), findsOneWidget);
      expect(find.text('Pizza'), findsOneWidget);
    });

    testWidgets('the search field filters the rows', (
      WidgetTester tester,
    ) async {
      final catalog = FakeAdminCatalogService(
        categories: <Category>[
          _category(id: 'c1', name: 'Burger'),
          _category(id: 'c2', name: 'Pizza'),
        ],
      );

      await tester.pumpWidget(
        _harness(
          const AdminCategoryListScreen(),
          catalogService: catalog,
        ),
      );
      await settleAdmin(tester);

      await tester.enterText(find.byType(TextField).first, 'piz');
      await settleAdmin(tester);

      expect(find.text('Burger'), findsNothing);
      expect(find.text('Pizza'), findsOneWidget);
    });
  });

  group('AdminCategoryFormScreen', () {
    testWidgets('refuses to save an empty name', (WidgetTester tester) async {
      final catalog = FakeAdminCatalogService();

      await tester.pumpWidget(
        _harness(
          const AdminCategoryFormScreen(),
          catalogService: catalog,
        ),
      );
      await settleAdmin(tester);

      await tester.tap(find.byType(BtnFrave));
      await settleAdmin(tester);

      expect(find.text('Vui lòng nhập tên danh mục'), findsOneWidget);
      expect(catalog.createdCategories, isEmpty);
    });

    testWidgets('saves a new category', (WidgetTester tester) async {
      final catalog = FakeAdminCatalogService();

      await tester.pumpWidget(
        _harness(
          const AdminCategoryFormScreen(),
          catalogService: catalog,
        ),
      );
      await settleAdmin(tester);

      await tester.enterText(
        find.byType(TextField).first,
        'Món mới',
      );
      await settleAdmin(tester);

      await tester.tap(find.byType(BtnFrave));
      await settleAdmin(tester);

      expect(catalog.createdCategories.length, 1);
      expect(catalog.createdCategories.first.category, 'Món mới');
    });
  });

  group('AdminProductListScreen', () {
    testWidgets('renders a row per product', (WidgetTester tester) async {
      final catalog = FakeAdminCatalogService(
        categories: <Category>[const Category(id: 'c1', category: 'Burger')],
        products: <Productsdb>[
          _product(id: 'p1', name: 'Combo Burger'),
          _product(id: 'p2', name: 'Pizza Hà Nội', categoryId: 'c2'),
        ],
      );

      await tester.pumpWidget(
        _harness(
          const AdminProductListScreen(),
          catalogService: catalog,
        ),
      );
      await settleAdmin(tester);

      expect(find.text('Quản lý món ăn'), findsOneWidget);
      expect(find.text('Combo Burger'), findsOneWidget);
      expect(find.text('Pizza Hà Nội'), findsOneWidget);
    });

    testWidgets('the category chips filter the rows', (
      WidgetTester tester,
    ) async {
      final catalog = FakeAdminCatalogService(
        categories: <Category>[
          const Category(id: 'c1', category: 'Burger'),
          const Category(id: 'c2', category: 'Pizza'),
        ],
        products: <Productsdb>[
          _product(id: 'p1', name: 'Combo Burger', categoryId: 'c1'),
          _product(id: 'p2', name: 'Pizza Hà Nội', categoryId: 'c2'),
        ],
      );

      await tester.pumpWidget(
        _harness(
          const AdminProductListScreen(),
          catalogService: catalog,
        ),
      );
      await settleAdmin(tester);

      // The "Pizza" chip sits in the filter row above the list.
      await tester.tap(find.text('Pizza').first);
      await settleAdmin(tester);

      expect(find.text('Combo Burger'), findsNothing);
      expect(find.text('Pizza Hà Nội'), findsOneWidget);
    });
  });

  group('AdminProductFormScreen', () {
    testWidgets('refuses to save without a name', (WidgetTester tester) async {
      _useTallViewport(tester);
      final catalog = FakeAdminCatalogService();

      await tester.pumpWidget(
        _harness(
          const AdminProductFormScreen(),
          catalogService: catalog,
        ),
      );
      await settleAdmin(tester);

      await tester.tap(find.byType(BtnFrave));
      await settleAdmin(tester);

      expect(find.text('Vui lòng nhập tên món'), findsOneWidget);
      expect(catalog.createdProducts, isEmpty);
    });

    testWidgets('saves a new product', (WidgetTester tester) async {
      _useTallViewport(tester);
      final catalog = FakeAdminCatalogService(
        categories: <Category>[const Category(id: 'c1', category: 'Burger')],
      );

      await tester.pumpWidget(
        _harness(
          const AdminProductFormScreen(),
          catalogService: catalog,
        ),
      );
      await settleAdmin(tester);

      await tester.enterText(find.byType(TextField).first, 'Món mới');
      await settleAdmin(tester);

      // The price field.
      await tester.enterText(find.byType(TextField).at(2), '12');
      await settleAdmin(tester);

      // The category dropdown.
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await settleAdmin(tester);
      await tester.tap(find.text('Burger').last);
      await settleAdmin(tester);

      await tester.tap(find.byType(BtnFrave));
      await settleAdmin(tester);

      expect(catalog.createdProducts.length, 1);
      expect(catalog.createdProducts.first.nameProduct, 'Món mới');
      expect(catalog.createdProducts.first.price, 12);
    });
  });
}
