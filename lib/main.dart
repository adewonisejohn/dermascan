import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:camera/camera.dart';
import 'package:dermascan/over_lay.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:tflite/tflite.dart';
import 'package:image/image.dart' as img;
import 'package:dermascan/prescripton.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';




void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner:false,
      title: 'Derma Scan',
      home: const MyHomePage(title: 'Derma Scan'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  bool is_camera=true;

  bool is_predicting = false;

  var output ;
  late List<CameraDescription> cameras;
  late CameraController cameraController;

  var _image;
  var _image_path;

  Future getImage() async{
    final image = await ImagePicker().pickImage(source:ImageSource.gallery);
    if(image==null) return;
    final imageTemporary = File(image.path);
    setState(() {
      this._image=imageTemporary;
      this._image_path=image.path;
      is_camera=false;
    });
  }

  void startCamera() async {
    cameras = await availableCameras();

    cameraController = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio:false
    );

    await cameraController.initialize().then((value){
      if(!mounted){
        return;
      }
      setState(() {});
    }).catchError((e){
      print(e);
    });

  }

  void take_picture() async{
    cameraController.setFlashMode(FlashMode.off);
    cameraController.takePicture().then((XFile? file){
      if(mounted){
        if(file !=null ){
          print("picture saved to ${file.path}");
          final imageTemporary = File(file.path);
          setState(() {
            this._image=imageTemporary;
            this._image_path=file.path;
            is_camera=false;
          });
        }
      }
    });
  }

  Future<void>_initTensorflow()async {
    String? res = await Tflite.loadModel(
        model: "assets/model2.tflite",
        labels: "assets/labels2.txt",
        numThreads: 1, // defaults to 1
        isAsset: true, // defaults to true, set to false to load resources outside assets
        useGpuDelegate: false // defaults to false, set to true to use GPU delegate
    );
    print("result after loading model ${res}");
  }

  Future<void> predict(var filepath) async{
    setState(() {
      this.is_predicting=true;
    });
    print('about to be predicted');

    final image = img.decodeImage(File(filepath).readAsBytesSync());

    final resizedImage = img.copyResize(image! , width:224, height:224);
    File(filepath).writeAsBytesSync(img.encodePng(resizedImage));

    print(filepath);

    var recognitions;
    recognitions = await Tflite.runModelOnImage(
        path:filepath,   // required
        imageMean: 0.0,   // defaults to 117.0
        imageStd: 255.0,  // defaults to 1.0
        numResults: 1,    // defaults to 5
        threshold: 0.2,   // defaults to 0.1
        asynch: true      // defaults to true
    );
    setState(() {
      output=recognitions;
    });

    print("-------------------------------------------------");
    print(output[0]["index"]);
    print(recognitions);
    print("--------------------------------------------------");
    setState(() {
      this.is_predicting=false;
    });
   if(output[0]["index"]==0){
     Navigator.push(
       context,
       MaterialPageRoute(builder: (context) =>prescription(file_path:filepath)),
     );
   }else{
     print("invalid disease");
     showDialog(context: context, builder: (BuildContext context){
       return AlertDialog(
         title: Center(child: Text("No disease found",style:GoogleFonts.montserrat(fontWeight:FontWeight.w600),)),
         content: Container(
           height:MediaQuery.of(context).size.height*0.2,
           child: Column(
             crossAxisAlignment:CrossAxisAlignment.center,
             mainAxisAlignment:MainAxisAlignment.center,
             children: [
               Icon(Icons.error_outline_outlined,size:55,color:Colors.red),
               SizedBox(height:20,),
               Center(child: Text("Make sure the subject correctly positioned at the center of the container",style:GoogleFonts.montserrat(fontWeight:FontWeight.w600),textAlign:TextAlign.center,)),
             ],
           ),
         ),
       );
     });
   }


  }

  @override
  void dispose(){
    cameraController.dispose();
    Tflite.close();
    super.dispose();
  }




  @override
  void initState(){
    startCamera();
    _initTensorflow();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {

   if(cameraController.value.isInitialized){

     return Scaffold(
         bottomNavigationBar:Container(
           height:MediaQuery.of(context).size.height*0.25,
           padding:EdgeInsets.only(top:MediaQuery.of(context).size.height*0.03),
           color:Colors.white,
           child:Column(
             crossAxisAlignment:CrossAxisAlignment.center,
             children: [
               Row(
                 crossAxisAlignment:CrossAxisAlignment.center,
                 mainAxisAlignment:MainAxisAlignment.spaceEvenly,
                 children: [
                   GestureDetector(
                     onTap:(){
                       print("picking from photos");
                       getImage();
                       /*setState(() {
                         is_camera=false;
                       });*/
                     },
                     child: Column(
                         children: [
                           Container(
                               width:80,
                               height:80,
                               child: Icon(Icons.photo_outlined,size:40,color:Color(0xff85FEA1),)
                           ),
                           SizedBox(height:7,),
                           Text("Photos")
                         ]
                     ),
                   ),
                   Column(
                       children:[Container(
                         width:80,
                         height:80,
                         decoration:BoxDecoration(
                             color:Color(0xff08B118),
                             borderRadius:BorderRadius.circular(50)
                         ),
                         child: Center(
                           child: Container(
                             width:70,
                             height:70,
                             decoration:BoxDecoration(
                                 color:Colors.white,
                                 borderRadius:BorderRadius.circular(50)
                             ),
                             child:Center(
                               child:is_camera?GestureDetector(
                                 onTap:(){
                                   take_picture();
                                 },
                                 child: Container(
                                   width:62,
                                   height:62,
                                   decoration:BoxDecoration(
                                       gradient: LinearGradient(
                                         begin: Alignment.topRight,
                                         end: Alignment.bottomLeft,
                                         colors: [
                                           Color(0xffc7f800),
                                           Color(0xff078513)
                                         ],
                                       ),
                                       ///color:Colors.black,
                                       borderRadius:BorderRadius.circular(50)
                                   ),
                                 ),
                               ):
                               GestureDetector(
                                 onTap:(){
                                   print("about to predict the selected image");
                                   predict(_image_path);
                                 },
                                 child: Container(
                                   width:62,
                                   height:62,
                                   decoration:BoxDecoration(
                                       color:Colors.white,
                                       borderRadius:BorderRadius.circular(50)
                                   ),
                                   child:Icon(Icons.check,size:50,color:Color(0xff08B118)),
                                 ),
                               ),
                             ),
                           ),
                         ),
                       ),
                         SizedBox(height:7,),
                         Text("Detect")
                       ]
                   ),
                   GestureDetector(
                     onTap:(){
                       setState(() {
                         cameraController.initialize();
                         _image="";
                         is_camera=true;
                       });
                     },
                     child: Column(
                       children: [
                         Container(
                             width:80,
                             height:80,
                             child: Icon(Icons.refresh,size:40,color:Color(0xff85FEA1),)
                         ),
                         SizedBox(height:7,),
                         Text("Reset")

                       ],
                     ),
                   )
                 ],
               ),
             ],
           ),
         ),
         body:is_predicting?Container(
           child:Center(
             child:CircularProgressIndicator(
               color:Colors.greenAccent,
             ),
           ),
         ):
             Stack(
             children:[
               Container(
                 width:double.infinity,
                   child: is_camera ? CameraPreview(cameraController) : Container(
                     width:double.infinity,
                     color:Colors.transparent,
                     height:double.infinity,
                     child:Image.file(_image,fit:BoxFit.fitHeight),
                   )
               ),

               Align(
                 alignment:Alignment.center,
                 child:QRScannerOverlay(overlayColour:Colors.black.withOpacity(0.5),),
               ),
               Align(
                   alignment:Alignment.bottomCenter,
                   child: Container(
                       margin:EdgeInsets.only(bottom:MediaQuery.of(context).size.height*0.025),
                       child: Text("Place the subject in the center",style:TextStyle(color:Colors.white),)
                   )
               )
             ]
         )
     );


   }else{
     return const SizedBox();
   }

  }
}
