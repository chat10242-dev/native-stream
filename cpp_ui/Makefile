CXX ?= g++
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra -Wpedantic -s -pthread
TARGET = native_stream_gui

all: $(TARGET)

$(TARGET): main.cpp ../stream_engine.cpp ../stream_engine.hpp
	$(CXX) $(CXXFLAGS) -o $@ main.cpp ../stream_engine.cpp

clean:
	rm -f $(TARGET)

.PHONY: all clean
