//�ӂ��ǂ�MME
//MMXX (c) SANDMAN presents!
//
//ikeno���� ikChromatic���Q�l�ɍ쐬���܂����B���肪�Ƃ��������܂��B
//

//�ȉ������������đ����Ƃ��w�����󂯂�R���g���[���Ƃ������������悤
#define LOOPNUM 25	//LOOPNUM * LOOPINNER���t�`�̐L�т�͈�(�s�N�Z����)�ɂȂ�܂��B�s�N�Z�����Ȃ̂ŏo�͎��ƕҏW���ŉ𑜓x���ς��ƈ�ۂ��ς��ł��傤
#define LOOPINNER 4	//LOOPINNER�������قǊp�x�����m�ɂȂ邯��((LOOPINNER*2+1)^2)*LOOPNUM�ɔ�Ⴕ�ďd���Ȃ�
static float MAX_FUTOSA = LOOPNUM * LOOPINNER;
#define CONTROLLER_NAME		"sdFuchidoriController.pmx" //�R���g���[���̃t�@�C����
#define MODULE_NAME sdFuchidori	//MMEffect�̃^�u�ɏo�閼�O������ŕς����܂�

#define MODULE_RT_DESC "Object map for sdFuchidori"

//�����/////////////////////////////


const float PI = 3.14159265359;
float2 ViewportSize : VIEWPORTPIXELSIZE;
static const float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static const float2 OnePixel = 1.0 / ViewportSize;
static float ViewportAspect = ViewportSize.x / ViewportSize.y;

float4 ClearColor  = float4(0,0,0,0);
float ClearDepth  = 1.0;

float3   CameraPosition    : POSITION < string Object = "Camera"; > ;
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 InvViewMatrix               : VIEWINVERSE;
float4x4 ProjectionMatrix         : PROJECTION;
float3 LightDirection : DIRECTION < string Object = "Light"; > ;
float3 LightAmbient     : AMBIENT < string Object = "Light"; > ;


float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "scene";
	string ScriptOrder = "postprocess";
> = 0.8;

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;

float ftime : TIME <bool SyncInEditMode=false;>;
float dtime : ELAPSEDTIME;

texture2D ScnMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 1;
	string Format = "D3DFMT_A16B16G16R16F";
>;
sampler2D ScnSamp = sampler_state {
	texture = <ScnMap>;
	MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
	AddressU  = WRAP; AddressV = WRAP;
};


//�t�`�ǂ点�������̂�����Ƃ���́AR=1
texture MODULE_NAME : OFFSCREENRENDERTARGET <
	string Description = MODULE_RT_DESC;
	string Format = "D3DFMT_R16F";
	float2 ViewPortRatio = { 1.0, 1.0 };
	float4 ClearColor = { 0,0,0, 1 };
	float ClearDepth = 1.0;
	bool AntiAlias = false;
	int Miplevels = 1;
	string DefaultEffect =
		"self=hide;"
		"*=sdFuchidotte.fx;"; > ;
sampler FuchiSamp = sampler_state {
	Texture = <MODULE_NAME>;
	MinFilter = POINT; MagFilter = POINT; MipFilter = POINT;
	AddressU = CLAMP; AddressV = CLAMP;
};


//�ʂɕ����t������Ȃ��񂾂��ǁA�����Ώۂ���̋����}�b�v
texture SDFMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = { 1.0,1.0 };
	int MipLevels = 1;
	string Format = "D3DFMT_R16F";
> ;
sampler SDFSamp = sampler_state {
	Texture = <SDFMap>;
	MinFilter = POINT; MagFilter = POINT; MipFilter = POINT;
	AddressU = CLAMP; AddressV = CLAMP;
};


texture SDFBackMap : RENDERCOLORTARGET <
	float2 ViewPortRatio = { 1.0,1.0 };
int MipLevels = 1;
string Format = "D3DFMT_R16F";
> ;
sampler SDFBackSamp = sampler_state {
	Texture = <SDFBackMap>;
	MinFilter = POINT; MagFilter = POINT; MipFilter = POINT;
	AddressU = CLAMP; AddressV = CLAMP;
};


float3 Hue(float hue)
{
	float3 rgb = frac(hue + float3(0.0, 2.0 / 3.0, 1.0 / 3.0));
	rgb = abs(rgb * 2.0 - 1.0);
	return clamp(rgb * 3.0 - 1.0, 0.0, 1.0);
}

//h=0..1
float3 HSVtoRGB(float3 hsv)
{
	return ((Hue(hsv.x) - 1.0) * hsv.y + 1.0) * hsv.z;
}

float3 RGBtoHSV(float3 rgb)
{
	const float third = 1.0 / 3.0;
	const float sixth = 1.0 / 6.0;
	float maxrgb = max(max(rgb.r, rgb.g), rgb.b);
	float minrgb = min(min(rgb.r, rgb.g), rgb.b);
	float sa = maxrgb - minrgb;
	float3 hsv;

	if (rgb.r == maxrgb) {
		hsv.r = sixth * (rgb.g - rgb.b) / sa;
	}
	else if (rgb.g == maxrgb) {
		hsv.r = sixth * (rgb.b - rgb.r) / sa + third;
	}
	else {
		hsv.r = sixth * (rgb.r - rgb.g) / sa + third * 2;
	}

	if (maxrgb < 0.0001)
		hsv.g = 0;
	else
		hsv.g = (maxrgb - minrgb) / maxrgb;

	hsv.b = maxrgb;
	return hsv;
}


//�����x(�A�N�Z�̃p�����[�^)
float acsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; > ;


//�萔�l�̃f�K���}
float Pow22C(float p) { return p ? pow(p, 2.2) : 0; }	
float3 Pow22C3(float3 p) { return float3(Pow22C(p.r), Pow22C(p.g), Pow22C(p.g)); }
//�R���g���[���̒l��0�Ȃ�f�t�H���g�l��Ԃ��A�����łȂ��Ȃ�set�l��Ԃ�
float DefDef(float x, float set, float def) { return (abs(x) < 0.0001) ? def : set; }

bool isExistController : CONTROLOBJECT < string name = CONTROLLER_NAME; > ;

float _BoundBias : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "���E�ڂ���"; > ;
static float BoundBias = _BoundBias * 16.0;

float _Futosa : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "����"; > ;
static float Futosa = (abs(_Futosa) < 0.001) ? 0.5 : _Futosa;

float _FuchiH : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "�F��"; > ;
float _FuchiS : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "�ʓx"; > ;
float _FuchiV : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "�P�x"; > ;
float _FuchiA : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "�����x"; > ;
static float4 FuchiColor = float4(HSVtoRGB(float3(_FuchiH, _FuchiS, _FuchiV)), (1-_FuchiA)*acsTr);

float OutFutosa : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "�O����"; > ;

float _OutFuchiH : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "�O�F��"; > ;
float _OutFuchiS : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "�O�ʓx"; > ;
float _OutFuchiV : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "�O�P�x"; > ;
float _OutFuchiA : CONTROLOBJECT < string name = CONTROLLER_NAME; string item = "�O�����x"; > ;
static float4 OutFuchiColor = float4(HSVtoRGB(float3(_OutFuchiH, _OutFuchiS, _OutFuchiV)), (1-_OutFuchiA)*acsTr);



int LoopCounter = LOOPNUM;

struct VS_OUTPUT {
	float4 Pos			: POSITION;
	float4 Tex			: TEXCOORD0;
};

VS_OUTPUT VS( float4 Pos : POSITION, float2 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0;

	Out.Pos = Pos;
	Out.Tex.xy = Tex + ViewportOffset;

	Out.Tex.zw = Out.Tex.xy - 0.5;
	Out.Tex.w /= ViewportAspect;

	return Out;
}


//�t���b�v
float4 FlipPS(float4 Tex: TEXCOORD0) : COLOR
{
	return tex2D(SDFBackSamp, Tex);
}


//1�s�N�Z���L����
float4 SpreadPS(float4 Tex: TEXCOORD0) : COLOR
{
	float d = 10000;

	for (int y = -LOOPINNER; y <= LOOPINNER; y++) {
		for (int x = -LOOPINNER; x <= LOOPINNER; x++) {
			float fmap = tex2Dlod(SDFSamp, float4(Tex + float2(x,y)*OnePixel,0,0)).r;
			d = min(d, fmap + length(float2(x, y)));
		}
	}
	return float4(d,d,d,1);
}


//�Z�b�g�A�b�v
float4 SetUpPS(float4 Tex: TEXCOORD0) : COLOR
{
	float fmap = tex2D(FuchiSamp,Tex).r;
	return (fmap.r) ? 0 : 10000;
}

//�{��PS
float4 PS(float4 Tex: TEXCOORD0) : COLOR
{
	float4 JIColor = tex2D(ScnSamp,Tex);
	float d = tex2D(SDFSamp,Tex).r;
	float4 Color = JIColor;

	//����
	float dens0 = d ? 0 : 1;
	float dens1 = 1 - smoothstep(MAX_FUTOSA * Futosa - BoundBias, MAX_FUTOSA * Futosa+ BoundBias, d);
	float dens2 = 1 - smoothstep(MAX_FUTOSA * OutFutosa - BoundBias, MAX_FUTOSA * OutFutosa + BoundBias, d);

	Color = lerp(JIColor, OutFuchiColor, dens2 * OutFuchiColor.a);		//�O���̃t�`
	Color = lerp(Color, FuchiColor, dens1 * FuchiColor.a); //�����̃t�`
	Color = lerp(Color, JIColor, dens0);

	Color.a = 1;
	return Color;
}


technique postprocessTest <
	string Script =
	"RenderColorTarget0=ScnMap;"
	"RenderDepthStencilTarget=DepthBuffer;"
	"ClearSetColor=ClearColor;"
	"ClearSetDepth=ClearDepth;"
	"Clear=Color;"
	"Clear=Depth;"
	"ScriptExternal=Color;"

	"RenderColorTarget0=SDFMap;"
	"Pass=SetUpSDF;"

	"LoopByCount=LoopCounter;"
	"RenderColorTarget0=SDFBackMap;"
	"Pass=SpreadSDF;"
	"RenderColorTarget0=SDFMap;"
	"Pass=Flip;"
	"LoopEnd=;"

	"RenderColorTarget0=;"
	"RenderDepthStencilTarget=;"
	"Pass=Draw1;"
	;
> {
	pass Flip < string Script = "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS();
		PixelShader = compile ps_3_0 FlipPS();
	}
	pass SpreadSDF < string Script = "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS();
		PixelShader = compile ps_3_0 SpreadPS();
	}
	pass SetUpSDF < string Script = "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS();
		PixelShader = compile ps_3_0 SetUpPS();
	}
	pass Draw1 < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable = FALSE;
		VertexShader = compile vs_3_0 VS();
		PixelShader  = compile ps_3_0 PS();
	}
}
