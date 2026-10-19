package com.nativeStream.asm;

import android.app.Activity;
import android.os.Bundle;
import android.widget.TextView;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        TextView text = new TextView(this);
        text.setTextSize(20f);
        text.setPadding(32, 32, 32, 32);
        text.setText("NativeStream ASM\nAndroid launcher ready\nNative ELF binary can be launched from app assets or data dir.");
        setContentView(text);
    }
}
