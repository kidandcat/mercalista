import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as imgLib;

List<CameraDescription> cameras;

void main() async {
  await GetStorage.init('lists');
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(GetMaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String marketlistSelected = '';
  var lists = GetStorage('lists');

  @override
  Widget build(BuildContext context) {
    var keys = lists.getKeys().toList();
    return MaterialApp(
      title: 'Mercalista',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: marketlistSelected == ''
          ? Scaffold(
              appBar: AppBar(
                title: Text('Market Lists'),
                actions: [
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () {
                      Get.defaultDialog(
                        title: '',
                        content: Container(
                          child: TextField(
                            onSubmitted: (value) {
                              setState(() {
                                marketlistSelected = value;
                              });
                              Get.back();
                            },
                          ),
                        ),
                      );
                    },
                  )
                ],
              ),
              body: Container(
                child: ListView.builder(
                  itemCount: keys.length,
                  itemBuilder: (context, index) => InkWell(
                    onTap: () {
                      setState(() {
                        marketlistSelected = keys[index];
                      });
                    },
                    child: Container(
                      color: Colors.green[100],
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.all(5),
                      child: Text(
                        keys[index],
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : MarketlistScreen(
              marketlistSelected,
              goBack: () {
                setState(() {
                  marketlistSelected = '';
                });
              },
            ),
    );
  }
}

class MarketlistScreen extends StatefulWidget {
  MarketlistScreen(this.listName, {this.goBack});
  final String listName;
  final Function goBack;

  @override
  _MarketlistScreenState createState() => _MarketlistScreenState(listName);
}

class _MarketlistScreenState extends State<MarketlistScreen> {
  CameraController controller;
  static const goScanner = const MethodChannel('be.galax.mercalista/goscanner');

  Marketlist marketlist;

  /// listName is the key used to store the list on disk, it must be unique
  String listName;
  bool showCamera = false;
  bool scanning = false;

  /// Receive listName as prop
  _MarketlistScreenState(this.listName) {
    marketlist = Marketlist(listName);
  }

  /// This is called only once when the Widget is added to the tree (useEffect)
  @override
  void initState() {
    super.initState();
    loadStorage();
    controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  /// GetStorage must be initialized per box or it will not load stored items
  void loadStorage() async {
    var ml = await Marketlist.load(listName);
    setState(() {
      marketlist = ml;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(listName),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            widget.goBack();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_forever),
            onPressed: () async {
              await marketlist.deleteList();
              widget.goBack();
            },
          )
        ],
      ),
      body: Center(
        child: !showCamera
            ? Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(15),
                    child: Text(
                      '${marketlist.totalPrice()}€',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 30,
                      ),
                    ),
                  ),
                  marketlist != null
                      ? Expanded(
                          child: ListView.builder(
                            itemCount: marketlist.size(),
                            itemBuilder: (context, index) => Container(
                              margin: const EdgeInsets.all(10),
                              height: 60,
                              child: Row(
                                children: [
                                  Text(
                                    '${marketlist.getProduct(index).quantity}x',
                                  ),
                                  if (marketlist.getProduct(index).image != '')
                                    Container(
                                      margin: const EdgeInsets.only(left: 5),
                                      child: Image.network(
                                        marketlist.getProduct(index).image,
                                      ),
                                    ),
                                  if (marketlist.getProduct(index).name != null)
                                    Expanded(
                                      child: Container(
                                        margin: const EdgeInsets.only(left: 5),
                                        child: Text(
                                          marketlist.getProduct(index).name,
                                        ),
                                      ),
                                    ),
                                  IconButton(
                                    icon: Icon(Icons.delete),
                                    onPressed: () {
                                      setState(() {
                                        marketlist.deleteProduct(index);
                                      });
                                    },
                                  ),
                                  Text(
                                      '${double.parse(marketlist.getProduct(index).price).toStringAsFixed(2)}€'),
                                ],
                              ),
                            ),
                          ),
                        )
                      : CircularProgressIndicator(),
                ],
              )
            : controller.value.isInitialized
                ? AspectRatio(
                    aspectRatio: MediaQuery.of(context).size.width /
                        MediaQuery.of(context).size.height,
                    child: CameraPreview(controller),
                  )
                : CircularProgressIndicator(),
      ),
      floatingActionButton: showCamera
          ? CircularProgressIndicator()
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  child: FloatingActionButton(
                    child: Icon(Icons.camera),
                    onPressed: () async {
                      try {
                        setState(() {
                          showCamera = true;
                        });
                        // give user 2 seconds to frame the barcode
                        await Future.delayed(Duration(seconds: 2));
                        await controller.startImageStream(processImage);
                      } catch (e) {
                        Get.defaultDialog(
                            title: 'Exception', middleText: e.toString());
                      }
                    },
                  ),
                ),
                FloatingActionButton(
                  child: Icon(Icons.add),
                  onPressed: () {
                    String name;
                    String price;
                    Get.defaultDialog(
                      title: 'Añadir',
                      content: Column(children: [
                        TextField(
                          onChanged: (value) => name = value,
                          decoration: InputDecoration(hintText: 'Nombre'),
                        ),
                        TextField(
                          keyboardType: TextInputType.number,
                          onChanged: (value) => price = value,
                          decoration: InputDecoration(hintText: 'Precio'),
                        ),
                        TextButton(
                          child: Text('OK'),
                          onPressed: () {
                            setState(() {
                              marketlist.addProduct(Product(
                                image:
                                    'https://cdn.onlinewebfonts.com/svg/img_343290.png',
                                name: name,
                                price: price,
                                quantity: 1,
                              ));
                            });
                            Get.back();
                          },
                        ),
                      ]),
                    );
                  },
                )
              ],
            ),
    );
  }

  void processImage(CameraImage img) async {
    print('-------------- processImage scanning = $scanning');
    if (scanning) return;
    setState(() {
      scanning = true;
    });
    await controller.stopImageStream();
    var data = await Conversor.convertYUV420toImage(img);
    var result = (await goScanner.invokeMethod('scan', data));
    print('RESULT $result');
    if (!isNumeric(result)) {
      Get.snackbar('Not found', 'Not found', backgroundColor: Colors.red);
    } else {
      var res = await http.get(
          'https://tienda.mercadona.es/api/products/${result.substring(7, 12)}');
      var p = Product.fromAPI(res.body);
      setState(() {
        marketlist.addProduct(p);
      });
      Get.snackbar('Success', 'Success', backgroundColor: Colors.green);
    }
    setState(() {
      scanning = false;
      showCamera = false;
    });
  }
}

bool isNumeric(String s) {
  if (s == null) {
    return false;
  }
  try {
    return double.parse(s) != null;
  } catch (e) {
    return false;
  }
}

class Marketlist {
  String name;
  GetStorage box;
  DateTime date;
  List<Product> elements = [];
  GetStorage lists = GetStorage('lists');

  static Future<Marketlist> load(String name) async {
    await GetStorage.init(name);
    return Marketlist(name);
  }

  Marketlist(String _name) {
    name = _name;
    box = GetStorage(name);
    lists.write(name, true);
    date = box.read('date');
    var els = box.read<List<dynamic>>('elements');
    if (els != null) elements = els.map((e) => Product.fromJson(e)).toList();
  }

  Future<void> deleteList() async {
    await lists.remove(name);
    await box.erase();
  }

  Marketlist.fromJson(Map<String, dynamic> json)
      : date = json['date'],
        elements = json['elements'].map((p) => Product.fromJson(p));

  Map<String, dynamic> toJson() => {
        'date': date,
        'elements': elements,
      };

  void addProduct(Product p) {
    try {
      var found = elements.firstWhere((e) => e.name == p.name);
      found.quantity++;
    } on StateError catch (_) {
      elements.add(p);
    }
    box.write('elements', elements.map((e) => e.toJson()).toList());
    box.save();
  }

  double totalPrice() {
    double res = 0;
    for (var e in elements) {
      res += double.parse(e.price) * e.quantity;
    }
    return res;
  }

  Product getProduct(int index) {
    return elements[index];
  }

  void deleteProduct(int index) {
    if (elements[index].quantity == 1) {
      elements.removeAt(index);
    } else {
      elements[index].quantity--;
    }
    box.write('elements', elements.map((e) => e.toJson()).toList());
    box.save();
  }

  void swapProducts(int a, int b) {
    var aProduct = elements[a];
    var bProduct = elements[b];
    elements[a] = bProduct;
    elements[b] = aProduct;
    box.write('elements', elements.map((e) => e.toJson()).toList());
    box.save();
  }

  int size() {
    return elements.length;
  }
}

class Product {
  String name;
  String image;
  String price;
  int quantity = 1;
  Product({this.name, this.image, this.price, this.quantity});

  @override
  String toString() {
    return 'Product(name: $name, image: $image, price: $price, quantity: $quantity)';
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'image': image,
      'price': price,
      'quantity': quantity,
    };
  }

  factory Product.fromAPI(String source) {
    var map = json.decode(source);
    return Product(
      name: map['display_name'],
      image: map['thumbnail'],
      price: map['price_instructions']['unit_price'],
      quantity: map.containsKey('quantity') ? map['quantity'] : 1,
    );
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    if (map == null) return null;

    return Product(
      name: map['name'],
      image: map['image'],
      price: map['price'],
      quantity: map['quantity'],
    );
  }

  String toJson() => json.encode(toMap());

  factory Product.fromJson(String source) =>
      Product.fromMap(json.decode(source));
}

class Conversor {
  static Future<Uint8List> convertYUV420toImage(CameraImage image) async {
    try {
      final int width = image.width;
      final int height = image.height;

      // imgLib -> Image package from https://pub.dartlang.org/packages/image
      var img = imgLib.Image(width, height); // Create Image buffer

      // Fill image buffer with plane[0] from YUV420_888
      for (int x = 0; x < width; x++) {
        for (int y = 0; y < height; y++) {
          final pixelColor = image.planes[0].bytes[y * width + x];
          // color: 0x FF  FF  FF  FF
          //           A   B   G   R
          // Calculate pixel color
          img.data[y * width + x] = (0xFF << 24) |
              (pixelColor << 16) |
              (pixelColor << 8) |
              pixelColor;
        }
      }
      List<int> png = imgLib.encodePng(img);
      return png;
    } catch (e) {
      print(">>>>>>>>>>>> ERROR:" + e.toString());
    }
    return null;
  }
}
