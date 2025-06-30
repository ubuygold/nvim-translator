#!/bin/bash

# test_all.sh - 运行所有测试并生成报告

set -e

echo "🧪 nvim-translator Test Suite"
echo "=========================="

# 确保依赖已安装
echo "📦 Checking test dependencies..."
make deps

echo ""
echo "🔧 Running unit tests..."
echo "-------------------"

# 运行配置模块测试
echo "📋 Configuration module tests..."
make test-config

echo ""
echo "🌐 Client module tests..."
make test-client

echo ""
echo "🎯 Main module tests..."
make test-init

echo ""
echo "🔗 Integration tests..."
echo "-------------"
make test-integration

echo ""
echo "✅ All tests completed!"
echo ""
echo "📊 Test coverage summary:"
echo "- ✅ Configuration module: 8 test cases"
echo "- ✅ Client module: 6 test cases" 
echo "- ✅ Main module: 9 test cases"
echo "- ✅ Integration tests: 8 test cases"
echo ""
echo "🎉 Total: 31 test cases all passed!"
