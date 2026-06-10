package com.briefingnow.app

import android.content.Context
import android.view.LayoutInflater
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class NativeAdFactoryFull(private val context: Context) :
    GoogleMobileAdsPlugin.NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView = LayoutInflater.from(context)
            .inflate(R.layout.native_ad_full, null) as NativeAdView

        val headline = adView.findViewById<TextView>(R.id.ad_headline)
        headline.text = nativeAd.headline
        adView.headlineView = headline

        val body = adView.findViewById<TextView>(R.id.ad_body)
        val bodyText = nativeAd.body
        if (bodyText.isNullOrEmpty()) {
            body.visibility = android.view.View.GONE
        } else {
            body.visibility = android.view.View.VISIBLE
            body.text = bodyText
        }
        adView.bodyView = body

        val cta = adView.findViewById<Button>(R.id.ad_call_to_action)
        val ctaText = nativeAd.callToAction
        if (ctaText.isNullOrEmpty()) {
            cta.visibility = android.view.View.INVISIBLE
        } else {
            cta.visibility = android.view.View.VISIBLE
            cta.text = ctaText
        }
        adView.callToActionView = cta

        val icon = adView.findViewById<ImageView>(R.id.ad_app_icon)
        val adIcon = nativeAd.icon
        if (adIcon == null) {
            icon.visibility = android.view.View.GONE
        } else {
            icon.visibility = android.view.View.VISIBLE
            icon.setImageDrawable(adIcon.drawable)
        }
        adView.iconView = icon

        val advertiser = adView.findViewById<TextView>(R.id.ad_advertiser)
        val advertiserText = nativeAd.advertiser ?: nativeAd.store
        if (advertiserText.isNullOrEmpty()) {
            advertiser.visibility = android.view.View.GONE
        } else {
            advertiser.text = advertiserText
            advertiser.visibility = android.view.View.VISIBLE
        }
        adView.advertiserView = advertiser

        val mediaView = adView.findViewById<MediaView>(R.id.ad_media)
        adView.mediaView = mediaView

        adView.setNativeAd(nativeAd)
        return adView
    }
}
