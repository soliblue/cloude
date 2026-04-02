#include <jni.h>
#include <string.h>
#include <stdlib.h>

extern char* cloude_encode_client_message(const char* json);
extern char* cloude_decode_server_message(const char* json);
extern void cloude_free_string(char* str);
extern char* cloude_bridge_version(void);

JNIEXPORT jstring JNICALL
Java_com_cloude_app_Services_SwiftBridge_nativeEncodeClientMessage(
    JNIEnv *env, jclass cls, jstring json) {
    const char *jsonStr = (*env)->GetStringUTFChars(env, json, NULL);
    if (!jsonStr) return NULL;
    char *result = cloude_encode_client_message(jsonStr);
    (*env)->ReleaseStringUTFChars(env, json, jsonStr);
    if (!result) return NULL;
    jstring jResult = (*env)->NewStringUTF(env, result);
    cloude_free_string(result);
    return jResult;
}

JNIEXPORT jstring JNICALL
Java_com_cloude_app_Services_SwiftBridge_nativeDecodeServerMessage(
    JNIEnv *env, jclass cls, jstring json) {
    const char *jsonStr = (*env)->GetStringUTFChars(env, json, NULL);
    if (!jsonStr) return NULL;
    char *result = cloude_decode_server_message(jsonStr);
    (*env)->ReleaseStringUTFChars(env, json, jsonStr);
    if (!result) return NULL;
    jstring jResult = (*env)->NewStringUTF(env, result);
    cloude_free_string(result);
    return jResult;
}

JNIEXPORT jstring JNICALL
Java_com_cloude_app_Services_SwiftBridge_nativeBridgeVersion(
    JNIEnv *env, jclass cls) {
    char *result = cloude_bridge_version();
    jstring jResult = (*env)->NewStringUTF(env, result);
    cloude_free_string(result);
    return jResult;
}
