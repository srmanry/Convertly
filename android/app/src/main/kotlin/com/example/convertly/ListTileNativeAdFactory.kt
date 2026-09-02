package com.example.convertly

import android.view.LayoutInflater
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.NativeAdFactory

/**
 * Builds the native ad that sits among the files list.
 *
 * The SDK needs each asset handed to it through the matching `set*View` call.
 * Populating a view without registering it means the ad renders but records no
 * impression, which looks like it is working while earning nothing.
 */
class ListTileNativeAdFactory(private val layoutInflater: LayoutInflater) :
    NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = layoutInflater.inflate(R.layout.native_ad_list_tile, null)
            as NativeAdView

        val headline = adView.findViewById<TextView>(R.id.ad_headline)
        headline.text = nativeAd.headline
        adView.headlineView = headline

        val body = adView.findViewById<TextView>(R.id.ad_body)
        // Every asset except the headline is optional, so anything missing is
        // hidden rather than left as an empty gap.
        if (nativeAd.body == null) {
            body.visibility = android.view.View.GONE
        } else {
            body.text = nativeAd.body
            body.visibility = android.view.View.VISIBLE
        }
        adView.bodyView = body

        val icon = adView.findViewById<ImageView>(R.id.ad_icon)
        val iconAsset = nativeAd.icon
        if (iconAsset == null) {
            icon.visibility = android.view.View.GONE
        } else {
            icon.setImageDrawable(iconAsset.drawable)
            icon.visibility = android.view.View.VISIBLE
        }
        adView.iconView = icon

        val callToAction = adView.findViewById<Button>(R.id.ad_call_to_action)
        if (nativeAd.callToAction == null) {
            callToAction.visibility = android.view.View.GONE
        } else {
            callToAction.text = nativeAd.callToAction
            callToAction.visibility = android.view.View.VISIBLE
        }
        adView.callToActionView = callToAction

        adView.setNativeAd(nativeAd)
        return adView
    }
}
