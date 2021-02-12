package be.galax.mercalista

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import scanner.Scanner
import java.lang.Exception

class MainActivity: FlutterActivity() {
    private val CHANNEL = "be.galax.mercalista/goscanner"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if(call.method == "scan"){
                val args = call.arguments
                if(args is ByteArray){
                    result.success(Scanner.scan(args as ByteArray))
                }else{
                    result.error("GO ERROR", "Arguments not valid, expecting Byte Array, got $args", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
