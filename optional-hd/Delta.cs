using System;
using System.IO;
using System.IO.Compression;
using System.Text;
public static class ZhDelta {
 public static void Apply(string source, string patch, string destination) {
  byte[] original=File.ReadAllBytes(source);
  using(var input=File.OpenRead(patch))
  using(var zip=new GZipStream(input,CompressionMode.Decompress))
  using(var r=new BinaryReader(zip))
  using(var output=new MemoryStream()) {
   if(Encoding.ASCII.GetString(r.ReadBytes(8))!="ZHTCDEL1") throw new InvalidDataException("Invalid patch header");
   uint size=r.ReadUInt32();
   if(size>67108864) throw new InvalidDataException("Patch too large");
   while(true) {
    byte op=r.ReadByte(); if(op==69) break;
    if(op==67) {
     uint at=r.ReadUInt32(), count=r.ReadUInt32();
     if((ulong)at+count>(ulong)original.Length || output.Length+count>size) throw new InvalidDataException("Copy outside file");
     output.Write(original,(int)at,(int)count);
    } else if(op==76) {
     uint count=r.ReadUInt32();
     if(output.Length+count>size) throw new InvalidDataException("Literal outside file");
     byte[] data=r.ReadBytes((int)count);
     if(data.Length!=count) throw new EndOfStreamException();
     output.Write(data,0,data.Length);
    } else throw new InvalidDataException("Invalid instruction");
   }
   if(output.Length!=size || r.BaseStream.ReadByte()!=-1) throw new InvalidDataException("Invalid result length");
   File.WriteAllBytes(destination,output.ToArray());
  }
 }
}
