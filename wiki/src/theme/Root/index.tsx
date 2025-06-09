import React from "react";
import { ToastContainer } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";

// Default implementation, that you can customize
export default function Root({ children }) {
  return (
    <>
      {children}
      <ToastContainer />
    </>
  );
}
