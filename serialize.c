/*
* lmarshal.c
* A Lua library for serializing and deserializing tables
* Richard Hundt <richardhundt@gmail.com>
*
* Provides:
* s = table.marshal(t)      - serializes a table to a byte stream
* t = table.unmarshal(s)    - deserializes a byte stream to a table
*
* Limitations:
* Coroutines are not serialized and nor are userdata, however support
* for userdata the __persist metatable hook can be used.
* 
* License: MIT
*
* Copyright (c) 2010 Richard Hundt
*
* Permission is hereby granted, free of charge, to any person
* obtaining a copy of this software and associated documentation
* files (the "Software"), to deal in the Software without
* restriction, including without limitation the rights to use,
* copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the
* Software is furnished to do so, subject to the following
* conditions:
*
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
* OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
* NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
* HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
* OTHER DEALINGS IN THE SOFTWARE.
*/

 #include <endian.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <assert.h>


//# include <bits/byteswap.h>
//#define htobe32(x) (x)

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

struct sheriff_buffer {
  char* begin;
  char* pos;
  char* end;
};

void sheriff_buffer_init( lua_State* L, struct sheriff_buffer* buf ){
  static const size_t start_size = 4096;
  buf->begin = (char*)malloc(start_size);
  if( buf->begin == NULL ) {
    luaL_error(L,"no memory for %d bytes",start_size);
  }
  buf->pos = buf->begin;
  buf->end = buf->begin + start_size;  
}

void sheriff_buffer_expand( lua_State* L, struct sheriff_buffer* buf, size_t min ){
  const size_t size = buf->end - buf->begin;
  const size_t off = buf->pos - buf->begin;
  const size_t new_size = size*2 > min*2 ? size*2 : min*2;
  buf->begin = (char*)realloc(buf->begin,new_size);
  if( buf->begin == NULL ) {
    free(buf->end-size);
    luaL_error(L, "no memory %d bytes",new_size);
  }
  buf->pos = buf->begin + off;
  buf->end = buf->begin + new_size;
}

void sheriff_buffer_write(  lua_State* L, struct sheriff_buffer* buf, const char* data, size_t len ){
  if(len > (buf->end - buf->pos)){
    sheriff_buffer_expand( L, buf, len );
  }
  memcpy(buf->pos,data,len);  
  buf->pos += len;
  //  printf("write len:%d\n",len);
}

static const char SHERIFF_TNUMBER = LUA_TNUMBER;
static const char SHERIFF_TTABLE = LUA_TTABLE;
static const char SHERIFF_TNONE = LUA_TNIL;
static const char SHERIFF_TSTRING = LUA_TSTRING;
static const char SHERIFF_TBOOLEAN = LUA_TBOOLEAN;


void sheriff_string(lua_State* L, int index, struct sheriff_buffer* buf ){
  size_t l;
  const char* s = lua_tolstring(L,index,&l);
  assert(s);
  sheriff_buffer_write(L,buf,(char*)&SHERIFF_TSTRING,1);
  //  uint32_t be_l = l; //htobe32(*(uint32_t*)&l);
  uint32_t be_l = htobe32(*(uint32_t*)&l);
  sheriff_buffer_write(L,buf,(char*)&be_l,sizeof(size_t));
  sheriff_buffer_write(L,buf,s,l);
}

void sheriff_number(lua_State* L, int index, struct sheriff_buffer* buf ){
  lua_Number n = lua_tonumber(L,index);
  //  uint64_t be_n = *(uint64_t*)&n; //htobe64(*(uint64_t*)&n);
  uint64_t be_n = htobe64(*(uint64_t*)&n);
  sheriff_buffer_write(L,buf,(char*)&SHERIFF_TNUMBER,1);
  sheriff_buffer_write(L,buf,(char*)&be_n,sizeof(lua_Number));
}

void sheriff_bool(lua_State* L, int index, struct sheriff_buffer* buf ){
  int8_t n = lua_toboolean(L,index);
  sheriff_buffer_write(L,buf,(char*)&SHERIFF_TBOOLEAN,1);
  sheriff_buffer_write(L,buf,(char*)&n,sizeof(int8_t));
}

void sheriff_number_index(lua_State* L, int index, struct sheriff_buffer* buf ){
  uint16_t n = (uint16_t)lua_tonumber(L,index);
  //  uint16_t be_n = n ;//htobe16(n);
  uint16_t be_n = htobe16(n);
  sheriff_buffer_write(L,buf,(char*)&SHERIFF_TNUMBER,1);
  sheriff_buffer_write(L,buf,(char*)&be_n,sizeof(uint16_t));
}

static void sheriff_table( lua_State* L, int index, struct sheriff_buffer* buf) {
  sheriff_buffer_write(L,buf,(char*)&SHERIFF_TTABLE,1);
  lua_pushnil(L);  
  while (lua_next(L, index) != 0) {
    int key_type = lua_type(L,-2);
    int value_type = lua_type(L,-1);
    switch(key_type) {
    case LUA_TNUMBER:
      sheriff_number_index(L,-2,buf);
      break;
    case LUA_TSTRING:
      sheriff_string(L,-2,buf);
      break;
    default:
      free(buf->begin);
      luaL_error(L,"unsuported key type %s",lua_typename(L,key_type));
      break;
    }
    switch(value_type) {
    case LUA_TNUMBER:
      sheriff_number(L,-1,buf);
      break;
    case LUA_TSTRING:
      sheriff_string(L,-1,buf);
      break;
    case LUA_TBOOLEAN:
      sheriff_bool(L,-1,buf);
      break;
    case LUA_TTABLE:
      sheriff_table(L,lua_gettop(L),buf);
      break;
    default:
      free(buf->begin);
      luaL_error(L,"unsuported value type %s",lua_typename(L,value_type));
      break;
    }
    lua_pop(L, 1);
  }
  sheriff_buffer_write(L,buf,(char*)&SHERIFF_TNONE,1);
}

static int sheriff(lua_State* L){
  struct sheriff_buffer buf;
  sheriff_buffer_init(L,&buf);
  if( lua_type(L,1) != LUA_TTABLE ){
    luaL_error(L,"no table");
  }
  sheriff_table(L,1,&buf);
  //  printf("b %p p %p e %p\n",buf.begin,buf.pos,buf.end);
  lua_pushlstring(L,buf.begin,buf.pos - buf.begin);
  free(buf.begin);
  return 1;
}

const char* unsheriff_buffer_read(struct sheriff_buffer* buf,size_t l){
  const char* p = buf->pos;
  buf->pos += l;
  assert(buf->pos < buf->end);
  return p;
}

size_t unsheriff_buffer_read_len(struct sheriff_buffer* buf){
  const char* p = buf->pos;
  buf->pos += sizeof(size_t);
  assert(buf->pos < buf->end);
  return (size_t)be32toh(*(size_t*)p);
}

char unsheriff_buffer_read_type(struct sheriff_buffer* buf){
  const char* p = buf->pos;
  ++buf->pos;
  assert(buf->pos <= buf->end);
  return *p;
}

static void unsheriff_string(lua_State* L, struct sheriff_buffer* buf){  
  size_t s = unsheriff_buffer_read_len(buf);
  const char* d = unsheriff_buffer_read(buf,s);
  lua_pushlstring(L,d,s);
}

static void unsheriff_number(lua_State* L, struct sheriff_buffer* buf){  
  uint64_t be_n = *(uint64_t*)(unsheriff_buffer_read(buf,sizeof(lua_Number)));
  uint64_t h_n = be64toh(be_n);
  lua_Number n = *(lua_Number*)(&h_n);
  lua_pushnumber(L,n);
}

static void unsheriff_bool(lua_State* L, struct sheriff_buffer* buf){  
    int n = (int)*unsheriff_buffer_read(buf,sizeof(uint8_t));
    lua_pushboolean(L,n);
}

static void unsheriff_number_index(lua_State* L, struct sheriff_buffer* buf){  
  uint16_t be_n = *(uint16_t*)unsheriff_buffer_read(buf,sizeof(uint16_t));
  uint16_t n = (uint16_t)be16toh(be_n);
  lua_pushnumber(L,n);
}


static void unsheriff_table(lua_State* L, struct sheriff_buffer* buf){
    int end = 0;
    lua_newtable(L);
  while(1){
    int key_type = unsheriff_buffer_read_type(buf);
    switch(key_type) {
    case LUA_TSTRING:
      unsheriff_string(L,buf);
      break;
    case LUA_TNUMBER:
      unsheriff_number_index(L,buf);
      break;
    case LUA_TNIL:
      end = 1;
      break;
    default:
      assert(0);
      break;    
    }
    if( end ){
      break;
    }
    int value_type = unsheriff_buffer_read_type(buf);
    switch(value_type) {
    case LUA_TSTRING:
      unsheriff_string(L,buf);
      break;
    case LUA_TNUMBER:
      unsheriff_number(L,buf);
      break;
    case LUA_TBOOLEAN:
      unsheriff_bool(L,buf);
      break;
    case LUA_TTABLE:
      unsheriff_table(L,buf);
      break;
    default:
      assert(0);
      break;    
    }  
    lua_settable(L,-3);
  }
}


static int unsheriff(lua_State* L){
  struct sheriff_buffer buf;
  size_t l;
  char type;
  if( lua_type(L,1) != LUA_TSTRING ){
    luaL_error(L,"no string");
  }  
  buf.begin = (char*)lua_tolstring(L,1,&l);
  buf.pos = buf.begin;
  buf.end = buf.begin + l;  
  type = unsheriff_buffer_read_type(&buf);
  if( type != LUA_TTABLE ){    
    luaL_error(L,"invalid type %d",type);
  }
  unsheriff_table(L,&buf);
  return 1;
}


static const luaL_reg R[] =
{
    {"sheriff",     sheriff},
    {"unsheriff",     unsheriff},
    {NULL,	    NULL}
};

int luaopen_marshal(lua_State *L)
{
  luaL_openlib(L, LUA_TABLIBNAME, R, 0);
    return 1;
}

