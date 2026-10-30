/* An experiment: SDL inside the launcher's app (bloodborne-launcher on iOS, a Tauri app that
 * owns UIApplication), before the game itself goes there. The launcher's Play calls
 * bb_ios_start_game on the main thread (its platform.rs, start_in_app); this one starts SDL
 * without SDL's own main and fills a full-screen window with slowly changing colours, pumping
 * events as the game's window loop does. It returns only if SDL could not start. */
#include <SDL3/SDL.h>
#define SDL_MAIN_HANDLED /* the app's main is Tauri's: SDL_main.h only for SDL_SetMainReady */
#include <SDL3/SDL_main.h>
#include <stdio.h>

/* Each line also into DATA/spike.log (the console of a Tauri app shows none of its output). */
static FILE *spike_log;
#define LOG(...) do { fprintf(stderr, __VA_ARGS__); if (spike_log) { fprintf(spike_log, __VA_ARGS__); fflush(spike_log); } } while (0)

int bb_ios_start_game(const char *data_dir) {
    char path[2048];
    snprintf(path, sizeof(path), "%s/spike.log", data_dir);
    spike_log = fopen(path, "w");
    LOG("Launcher spike: starting SDL (data %s)\n", data_dir);
    SDL_SetMainReady(); /* SDL's main did not run: UIKit is already up (Tauri's) */
    if (!SDL_Init(SDL_INIT_VIDEO)) {
        LOG("Launcher spike: SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }
    SDL_Window *window = SDL_CreateWindow("Bloodborne", 0, 0, SDL_WINDOW_FULLSCREEN | SDL_WINDOW_HIGH_PIXEL_DENSITY);
    if (!window) {
        LOG("Launcher spike: SDL_CreateWindow failed: %s\n", SDL_GetError());
        return 2;
    }
    LOG("Launcher spike: window created (shown %d)\n", !(SDL_GetWindowFlags(window) & SDL_WINDOW_HIDDEN));
    SDL_ShowWindow(window);
    SDL_RaiseWindow(window);
    SDL_Renderer *renderer = SDL_CreateRenderer(window, NULL);
    if (!renderer) {
        LOG("Launcher spike: SDL_CreateRenderer failed: %s\n", SDL_GetError());
        return 3;
    }
    LOG("Launcher spike: window and renderer (%s) up\n", SDL_GetRendererName(renderer));
    for (Uint64 frame = 0;; ++frame) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
        }
        const float t = (float)(frame % 360) / 360.0f;
        SDL_SetRenderDrawColorFloat(renderer, t, 0.2f, 1.0f - t, 1.0f);
        SDL_RenderClear(renderer);
        SDL_RenderPresent(renderer);
        if (frame % 120 == 0) LOG("Launcher spike: frame %llu\n", (unsigned long long)frame);
        SDL_Delay(16);
    }
}
