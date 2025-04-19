package com.epigeos.reo;

import org.libsdl.app.SDLActivity;

public class MainActivity extends SDLActivity {
    protected String[] getLibraries() {
        return new String[] { "SDL3", "REO" };
    }
}
