package kz.yokosun.yokomarket;

import android.os.Bundle;
import androidx.core.splashscreen.SplashScreen;
import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        SplashScreen.installSplashScreen(this);
        super.onCreate(savedInstanceState);
    }
}
