// __multiversion__
#include "fragmentVersionCentroid.h"
#include "uniformShaderConstants.h"
#include "uniformPerFrameConstants.h"

#if __VERSION__ >= 300
	#ifndef BYPASS_PIXEL_SHADER
		_centroid in highp vec2 uv0;
		_centroid in highp vec2 uv1;
	#endif
#else
	#ifndef BYPASS_PIXEL_SHADER
		varying vec2 uv0;
		varying vec2 uv1;
	#endif
#endif

LAYOUT_BINDING(0) uniform sampler2D TEXTURE_0;
LAYOUT_BINDING(1) uniform sampler2D TEXTURE_1;
LAYOUT_BINDING(2) uniform sampler2D TEXTURE_2;

precision highp float;
varying vec4 vcolor;
varying vec3 sunCol;
varying vec3 moonCol;
varying vec3 szCol;
varying vec3 cPos;
varying vec3 wPos;
varying vec3 nWPos;
varying vec3 lPos;
varying vec3 tlPos;
varying float sunVis;
varying float moonVis;

#include "common.glsl"

// https://github.com/origin0110/OriginShader/blob/main/shaders/glsl/shaderfunction.lin
float getleaao(vec3 color){
	const vec3 O = vec3(0.682352941176471, 0.643137254901961, 0.164705882352941);
	const vec3 N = vec3(0.195996912842436, 0.978673548072766, -0.061508507207520);
	return length(color) / dot(O, N) * dot(normalize(color), N);
}

float getgraao(vec3 color){
	const vec3 O = vec3(0.745098039215686, 0.713725490196078, 0.329411764705882);
	const vec3 N = vec3(0.161675377098328, 0.970052262589970, 0.181272392504186);
	return length(color) / dot(O, N) * dot(normalize(color), N);
}

vec3 calcVco(vec4 color){
	if(abs(color.x - color.y) < 2e-5 && abs(color.y - color.z) < 2e-5) color.rgb = vec3(1.0); else {
		color.a = color.a < 0.001 ? getleaao(color.rgb) : getgraao(color.rgb);
		color.rgb = color.rgb / color.a;
	}
	return color.rgb;
}

/*
float specGGX(vec3 N, float nDotL, float nDotV, float nDotH, float roughness){
	float rs = pow(roughness, 4.0);
	float d = (nDotH * rs - nDotH) * nDotH + 1.0;
	float nd = rs / (pi * d * d);
	float k = (roughness * roughness) * 0.5;
	float v = nDotV * (1.0 - k) + k, l = nDotL * (1.0 - k) + k;
	return max0(nd * (0.25 / (v * l)));
}

vec4 reflection(vec4 albedo, vec3 abl, vec3 N, float met, float ssm, float outD, float nDotV){
	vec3 rVector = reflect(normalize(wPos), N);
	vec3 skyRef = csky(rVector, lPos);
		skyRef = mix(skyRef, skyRef * abl, met);
	vec3 F0 = mix(vec3(0.04), abl, met);
	vec3 fSchlick = F0 + (1.0 - F0) * pow(1.0 - nDotV, 5.0);
	albedo.rgb = mix(albedo.rgb, albedo.rgb * 0.03, met);
	albedo = mix(albedo, vec4(skyRef, 1.0), vec4(fSchlick, length(fSchlick)) * max(ssm, wrain * N.y * 0.0) * outD);
	return albedo;
}
*/

void main(){

#ifdef BYPASS_PIXEL_SHADER
	gl_FragColor = vec4(0.0, 0.0, 0.0, 0.0);
	return;
#else
	vec4 albedo = texture(TEXTURE_0, uv0);
	#ifdef SEASONS_FAR
		albedo.a = 1.0;
	#endif
	#ifdef ALPHA_TEST
		#ifdef ALPHA_TO_COVERAGE
			if(albedo.a < 0.05) discard;
		#else
			if(albedo.a < 0.5) discard;
		#endif
	#endif
	#ifndef SEASONS
		#if !defined(ALPHA_TEST) && !defined(BLEND)
			albedo.a = vcolor.a;
		#endif
		albedo.rgb *= calcVco(vcolor);
	#else
		albedo.rgb *= mix(vec3(1.0), texture2D(TEXTURE_2, vcolor.rg).rgb * 2.0, vcolor.b);
		albedo.rgb *= vcolor.aaa;
		albedo.a = 1.0;
	#endif
		albedo.rgb = toLinear(albedo.rgb);

	float blSource = uv1.x * max(smoothstep(sunVis * uv1.y, 1.0, uv1.x), wrain * uv1.y), outD = smoothstep(0.845, 0.87, uv1.y);
	vec3 ambCol = szCol * uv1.y + vec3(BLOCK_LIGHT_C_R, BLOCK_LIGHT_C_G, BLOCK_LIGHT_C_B) * blSource + pow(blSource, 5.0) * 1.2, abl = albedo.rgb;

	vec3 N = normalize(cross(dFdx(cPos.xyz), dFdy(cPos.xyz)));
	float nDotL = max0(dot(N, tlPos));
		ambCol += (sunCol + moonCol) * nDotL * outD * (1.0 - wrain);
		albedo.rgb = (albedo.rgb * ambCol);

	float fdist = max0(length(wPos) / FOG_DISTANCE);
		albedo.rgb = mix(albedo.rgb, szCol, fdist * mix(mix(SS_FOG_INTENSITY, NOON_FOG_INTENSITY, sunVis), RAIN_FOG_INTENSITY, wrain));
		albedo.rgb += sunCol * mPhase(max0(1.0 - distance(nWPos, lPos)), FOG_MIE_G) * fdist * FOG_MIE_COEFF;

		albedo.rgb = colorCorrection(albedo.rgb);

	gl_FragColor = albedo;

#endif
}
