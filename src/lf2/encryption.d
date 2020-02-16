module lf2.encryption;

version(LF2LBF):

const ubyte[] cryptoKey = cast(ubyte[])"SiuHungIsAGoodBearBecauseHeIsVeryGood";

ubyte[] decryptData(const(ubyte)[] data, const(ubyte)[] key = cryptoKey, size_t additionalNonsense = 123)
{
	if (data.length <= additionalNonsense)
		return null;
	
	ubyte[] result = new ubyte[data.length - additionalNonsense];
	
	for (size_t i = 0; i < result.length; i++)
		result[i] = cast(ubyte)(data[i + additionalNonsense] - key[(i + additionalNonsense) % $]);
	
	return result;
}

ubyte[] encryptData(const(ubyte)[] data, const(ubyte)[] key = cryptoKey, size_t additionalNonsense = 123)
{
	ubyte[] result = new ubyte[data.length + additionalNonsense];
	
	for (size_t i = 0; i < additionalNonsense; i++)
		result[i] = ubyte.max;
	
	for (size_t i = additionalNonsense; i < result.length; i++)
		result[i] = cast(ubyte)(data[i] + key[i % $]);
	
	return result;
}
